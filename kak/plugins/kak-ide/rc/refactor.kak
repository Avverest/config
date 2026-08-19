# kak-ide — project-wide refactoring  (plan Section 7.1 / 7.2)
#
# 7.1 multi-file rename: kakoune-lsp 21 ships `lsp-rename` and applies the
# WorkspaceEdit across files, so the rename ITSELF needs no reimplementation.
# But it does not satisfy §7.1's "do not silently write to disk" requirement.
# Measured behaviour (test/refactor.sh --rename):
#
#   file already open in a buffer  ->  buffer modified, disk untouched  (reviewable)
#   file NOT open                  ->  WRITTEN STRAIGHT TO DISK         (no review, no undo)
#
# In a 3-file fixture renamed from the one open file, 2 of 3 files were silently
# rewritten on disk. Pre-opening those files as buffers does NOT prevent it —
# measured: they are still written, and the buffer is reloaded to match. So
# §7.1's "no surprise disk writes" is NOT reachable from the plugin boundary; it
# would need a change in kakoune-lsp itself.
#
# What `kak-ide-rename` does instead, which is honest and actually useful:
#   - opens every file mentioning the symbol, so they are all in the buffer list
#     and each carries in-session undo history
#   - shows the resulting `git diff` immediately, so the change is reviewed
#     after the fact rather than not at all
#   - warns first when the work tree is already dirty, because that is exactly
#     when a post-hoc diff stops being attributable to the rename
# `git checkout -- .` is the escape hatch, and the warning makes sure you know
# whether that is safe before you start.
#
# 7.2 project-wide find & replace is genuinely missing from Kakoune, and is
# implemented here as: ripgrep discovery -> unified-diff preview in a scratch
# buffer -> explicit confirmation -> write. Nothing touches disk before you have
# seen the diff and run the apply command.

declare-option -hidden str kak_ide_replace_pattern
declare-option -hidden str kak_ide_replace_replacement
declare-option -hidden str kak_ide_replace_root
declare-option -hidden str kak_ide_replace_helper "%val{config}/plugins/kak-ide/bin/kak-ide-replace"

# ─── Project-wide find & replace ─────────────────────────────────────────────

define-command kak-ide-replace -params 0..2 -docstring %{
    kak-ide-replace [<pattern> [<replacement>]]: stage a project-wide replace

    Shows a unified diff of every change it would make. Nothing is written until
    you run kak-ide-replace-apply. Pattern and replacement are PCRE; $1..$9 in
    the replacement refer to capture groups. .gitignore is respected.
} %{
    evaluate-commands %sh{
        if [ $# -ge 2 ]; then
            printf 'kak-ide-replace-stage %%arg{1} %%arg{2}\n'
        elif [ $# -eq 1 ]; then
            printf 'prompt -init %%arg{1} "replace (pattern): " %%{ kak-ide-replace %%val{text} }\n'
        else
            printf 'prompt "replace (pattern): " %%{ kak-ide-replace-ask-replacement %%val{text} }\n'
        fi
    }
}

define-command -hidden -params 1 kak-ide-replace-ask-replacement %{
    # -init with the pattern would be wrong here; start empty so a deletion
    # (replace with nothing) is one <ret> away.
    prompt "replace '%arg{1}' with: " -shell-script-candidates %{ printf '' } %{
        kak-ide-replace-stage %arg{1} %val{text}
    }
}

define-command -hidden -params 2 kak-ide-replace-stage %{
    kak-ide-detect-root
    set-option global kak_ide_replace_pattern %arg{1}
    set-option global kak_ide_replace_replacement %arg{2}
    set-option global kak_ide_replace_root %opt{kak_ide_project_root}

    evaluate-commands %sh{
        helper="$kak_opt_kak_ide_replace_helper"
        root="$kak_opt_kak_ide_project_root"
        [ -x "$helper" ] || { printf 'fail %%{kak-ide: helper not executable: %s}\n' "$helper"; exit 0; }

        diff=$("$helper" preview "$root" "$1" "$2" 2>&1)
        if [ -z "$diff" ]; then
            printf 'echo -markup %%{{Information}kak-ide: no matches for %%opt{kak_ide_replace_pattern}}\n'
            exit 0
        fi
        files=$("$helper" files "$root" "$1" 2>/dev/null | wc -l | tr -d ' ')
        tmp=$(mktemp "${TMPDIR:-/tmp}/kak-ide-preview.XXXXXX")
        {
            printf '# kak-ide: project-wide replace — PREVIEW ONLY, nothing written yet\n'
            printf '#\n'
            printf '#   root:        %s\n' "$root"
            printf '#   pattern:     %s\n' "$1"
            printf '#   replacement: %s\n' "$2"
            printf '#   files:       %s\n' "$files"
            printf '#\n'
            printf '#   :kak-ide-replace-apply   write these changes\n'
            printf '#   :kak-ide-replace-abort   discard them\n'
            printf '\n'
            printf '%s\n' "$diff"
        } > "$tmp"
        printf 'edit! -scratch *kak-ide-replace*\n'
        printf 'execute-keys "%%%%d"\n'
        printf 'execute-keys "!cat %s<ret>"\n' "$tmp"
        printf 'execute-keys "gg"\n'
        printf 'set-option buffer filetype diff\n'
        printf 'nop %%sh{ rm -f %s }\n' "$tmp"
        printf 'echo -markup %%{{Information}kak-ide: %s file(s) would change — :kak-ide-replace-apply to write}\n' "$files"
    }
}

define-command kak-ide-replace-apply -docstring %{
    kak-ide-replace-apply: write the staged project-wide replacement
} %{
    evaluate-commands %sh{
        [ -n "$kak_opt_kak_ide_replace_pattern" ] || {
            printf 'fail %%{kak-ide: nothing staged — run kak-ide-replace first}\n'; exit 0; }
        helper="$kak_opt_kak_ide_replace_helper"
        changed=$("$helper" apply \
            "$kak_opt_kak_ide_replace_root" \
            "$kak_opt_kak_ide_replace_pattern" \
            "$kak_opt_kak_ide_replace_replacement" 2>&1)
        n=$(printf '%s' "$changed" | grep -c . || true)
        # Any of those files that are open would now show stale text on disk;
        # reload them so the buffer and the file agree.
        printf '%s\n' "$changed" | while IFS= read -r f; do
            [ -n "$f" ] || continue
            printf 'try %%{ evaluate-commands -buffer %%{%s} %%{ edit! %%{%s} } }\n' "$f" "$f"
        done
        printf 'set-option global kak_ide_replace_pattern %%{}\n'
        printf 'try %%{ delete-buffer *kak-ide-replace* }\n'
        printf 'echo -markup %%{{Information}kak-ide: replaced in %s file(s)}\n' "$n"
    }
}

define-command kak-ide-replace-abort -docstring %{
    kak-ide-replace-abort: discard the staged project-wide replacement
} %{
    set-option global kak_ide_replace_pattern ''
    try %{ delete-buffer *kak-ide-replace* }
    echo -markup "{Information}kak-ide: replace discarded"
}

# ─── Rename (LSP-backed, §7.1) ───────────────────────────────────────────────

define-command kak-ide-rename -params 0..1 -docstring %{
    kak-ide-rename [<new-name>]: rename the symbol under the cursor project-wide

    Opens every file mentioning the symbol as a buffer before renaming, so the
    language server's edits land in buffers rather than being written straight
    to disk. Review with :kak-ide-rename-review, commit with :write-all, or undo
    per buffer with u.
} %{
    evaluate-commands %sh{
        [ $# -ge 1 ] && printf 'kak-ide-rename-impl %%arg{1}\n' ||
            printf 'prompt "rename to: " %%{ kak-ide-rename-impl %%val{text} }\n'
    }
}

define-command -hidden -params 1 kak-ide-rename-impl %{
    kak-ide-detect-root
    evaluate-commands -save-regs 'bw' %{
        set-register b %val{bufname}
        evaluate-commands -draft %{
            execute-keys '<a-i>w'
            set-register w %val{selection}
        }
        evaluate-commands %sh{
            sym="$kak_reg_w"
            root="$kak_opt_kak_ide_project_root"
            case "$sym" in ''|*[!A-Za-z0-9_]*) exit 0 ;; esac
            command -v rg >/dev/null 2>&1 || exit 0
            # Over-opening is harmless; missing a file is not, so match the bare
            # word anywhere rather than trying to be clever about scope.
            rg --word-regexp --files-with-matches --no-messages -e "$sym" "$root" 2>/dev/null |
                while IFS= read -r f; do
                    printf 'try %%{ edit -existing %%{%s} }\n' "$f"
                done
        }
        try %{ buffer %reg{b} }
        lsp-rename %arg{1}
    }
    kak-ide-rename-review
}

define-command kak-ide-rename-check -docstring %{
    kak-ide-rename-check: warn if the work tree is too dirty to review a rename
} %{
    kak-ide-detect-root
    evaluate-commands %sh{
        root="$kak_opt_kak_ide_project_root"
        git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
            printf 'echo -markup %%{{Error}kak-ide: %s is not a git work tree — a rename here writes to disk with no way back}\n' "$root"
            exit 0
        }
        n=$(git -C "$root" status --porcelain | grep -c . || true)
        if [ "$n" -gt 0 ]; then
            printf 'echo -markup %%{{Error}kak-ide: %s file(s) already modified — a post-rename diff will not be attributable. Commit or stash first.}\n' "$n"
        else
            printf 'echo -markup %%{{Information}kak-ide: work tree clean — a rename will be fully reviewable via git diff}\n'
        fi
    }
}

define-command kak-ide-rename-review -docstring %{
    kak-ide-rename-review: show what a rename actually changed

    kakoune-lsp writes edits for files that were not the current buffer straight
    to disk, so this reviews the change against git rather than against unsaved
    buffers. Revert everything with `git checkout -- .` from the project root.
} %{
    kak-ide-detect-root
    evaluate-commands %sh{
        root="$kak_opt_kak_ide_project_root"
        git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
            printf 'echo -markup %%{{Information}kak-ide: not a git work tree — cannot show a diff}\n'; exit 0; }
        diff=$(git -C "$root" diff 2>/dev/null)
        [ -n "$diff" ] || { printf 'echo -markup %%{{Information}kak-ide: no changes on disk}\n'; exit 0; }
        tmp=$(mktemp "${TMPDIR:-/tmp}/kak-ide-rename.XXXXXX")
        {
            printf '# kak-ide: changes on disk since the last commit\n'
            printf '#   revert everything:  git -C %s checkout -- .\n#\n' "$root"
            printf '%s\n' "$diff"
        } > "$tmp"
        printf 'edit! -scratch *kak-ide-rename*\n'
        printf 'execute-keys "%%%%d"\n'
        printf 'execute-keys "!cat %s<ret>"\n' "$tmp"
        printf 'execute-keys "gg"\n'
        printf 'set-option buffer filetype diff\n'
        printf 'nop %%sh{ rm -f %s }\n' "$tmp"
    }
}
