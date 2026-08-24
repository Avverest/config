# kak-ide — picker core  (plan Section 7.4)
#
# ARCHITECTURE: Kakscript over fzf.kak, not a Rust sidecar. See the RESOLVED
# decision record in KAKOUNE-PARITY-PLAN.md §5. fzf.kak's generic `fzf` command
# (-items-cmd / -kak-cmd / -filter / -fzf-args / -preview-cmd) is the primitive
# every picker below is built on, and fzf itself is already a fast compiled
# fuzzy matcher, so there is no matching cost to reclaim by writing a daemon.
#
# What this module adds over stock fzf.kak: a git changed-file picker, a command
# palette, a recent-locations picker, last-picker recall, and one `<space>`
# leader mode that reaches all of them plus the LSP-backed pickers — so symbols,
# diagnostics, files and search are all one keystroke apart instead of spread
# across three plugins' conventions.

# NOTE: fzf.kak is loaded by plug.kak later in kakrc than this module, so it is
# required lazily inside each command rather than at load time. The project-aware
# `fzf-project-*` commands live in kakrc's plug config block and likewise only
# exist once that block has run — which it has, by the time a key is pressed.

declare-option -docstring "the last picker that ran, for kak-ide-picker-last" \
    str kak_ide_last_picker

declare-option -docstring "how many recent locations to keep" \
    int kak_ide_jump_ring_size 60

declare-option -hidden str-list kak_ide_jump_ring

# Every picker registers itself here so `<space>'` can replay it.
define-command -hidden -params 1 kak-ide-picker-remember %{
    set-option global kak_ide_last_picker %arg{1}
}

define-command kak-ide-picker-last -docstring %{
    kak-ide-picker-last: re-open the picker that ran most recently
} %{
    evaluate-commands %sh{
        if [ -n "$kak_opt_kak_ide_last_picker" ]; then
            printf '%s\n' "$kak_opt_kak_ide_last_picker"
        else
            printf 'echo -markup %%{{Information}kak-ide: no picker has run yet}\n'
        fi
    }
}

# ─── Files / buffers / search ────────────────────────────────────────────────
#
# These delegate to the project-aware commands already defined in kakrc, and
# only add last-picker registration so they participate in `<space>'`.

define-command kak-ide-picker-files -docstring %{
    kak-ide-picker-files: fuzzy-find a file under the project root
} %{
    kak-ide-picker-remember kak-ide-picker-files
    fzf-project-files
}

define-command kak-ide-picker-files-cwd -docstring %{
    kak-ide-picker-files-cwd: fuzzy-find a file next to the current buffer
} %{
    kak-ide-picker-remember kak-ide-picker-files-cwd
    require-module fzf-file
    fzf-file buffile-dir
}

define-command kak-ide-picker-buffers -docstring %{
    kak-ide-picker-buffers: switch buffer
} %{
    kak-ide-picker-remember kak-ide-picker-buffers
    require-module fzf-buffer
    fzf-buffer
}

define-command kak-ide-picker-grep -docstring %{
    kak-ide-picker-grep: search file contents under the project root
} %{
    kak-ide-picker-remember kak-ide-picker-grep
    fzf-project-grep
}

# (split-opening moved to splits.kak — tmux-backed)

define-command kak-ide-picker-files-vsplit -docstring %{
    kak-ide-picker-files-vsplit: find a file and open it in a pane to the right
} %{
    kak-ide-picker-remember kak-ide-picker-files-vsplit
    require-module fzf
    kak-ide-picker-files-split-impl kak-ide-open-vsplit
}

define-command kak-ide-picker-files-hsplit -docstring %{
    kak-ide-picker-files-hsplit: find a file and open it in a pane below
} %{
    kak-ide-picker-remember kak-ide-picker-files-hsplit
    require-module fzf
    kak-ide-picker-files-split-impl kak-ide-open-hsplit
}

define-command -hidden -params 1 kak-ide-picker-files-split-impl %{
    kak-ide-detect-root
    evaluate-commands %sh{
        root="$kak_opt_kak_ide_project_root"
        if command -v fd >/dev/null 2>&1; then
            items="fd --type f --follow --hidden --exclude .git"
        else
            items="rg -L --hidden --files --glob '!.git/*'"
        fi
        printf 'fzf -kak-cmd %%{%s} -preview -items-cmd %%{cd %s && %s} -filter %%{sed "s|^|%s/|"} -fzf-args %%{--reverse}\n' \
            "$1" "$root" "$items" "$root"
    }
}

# ─── Changed files (git) ─────────────────────────────────────────────────────

define-command kak-ide-picker-changed -docstring %{
    kak-ide-picker-changed: pick from files changed vs. HEAD
} %{
    kak-ide-picker-remember kak-ide-picker-changed
    require-module fzf
    kak-ide-detect-root
    evaluate-commands %sh{
        root="$kak_opt_kak_ide_project_root"
        if ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            printf 'fail %%{kak-ide: %s is not a git work tree}\n' "$root"
            exit 0
        fi
        # Porcelain is exactly "XY<space>path". Keep it verbatim: the status
        # flags stay visible as fzf field 1 (so the query can be scoped to them
        # with --nth), and the path is field 2. An earlier `cut` that dropped
        # the separator glued them together and broke --nth entirely.
        items="git -C '$root' status --porcelain --untracked-files=normal"
        # Diff for tracked files; fall back to the file itself for untracked
        # ones, where `git diff` prints nothing. `grep .` fails on empty input,
        # which is what selects the fallback.
        prev="--preview 'git -C \"$root\" diff --color=always -- {2} | head -400 | grep . || cat \"$root/{2}\" 2>/dev/null'"
        printf 'info -title %%{changed files} %%{root: %s}\n' "$root"
        # -filter strips the status column, resolves renames ("old -> new") to
        # the new path, and makes the path absolute so `edit` works from any cwd.
        printf "fzf -kak-cmd %%{edit -existing} -preview -preview-cmd %%{%s} -items-cmd %%{%s} -filter %%{sed -E 's/^.. //; s/^.* -> //; s|^|%s/|'} -fzf-args %%{--reverse --nth=2..}\n" \
            "$prev" "$items" "$root"
    }
}

# ─── Recent locations ────────────────────────────────────────────────────────
#
# NOT Kakoune's jumplist. Kakoune keeps a jumplist for <c-o>/<c-i> but exposes
# no value to read it from, so a faithful jumplist picker is not reachable from
# the plugin boundary (it would need a core patch). This is a ring of positions
# recorded whenever a buffer is displayed — which is what a jumplist picker is
# actually used for — and is named for what it is rather than what it imitates.

define-command -hidden kak-ide-jump-record %{
    evaluate-commands %sh{
        [ -n "$kak_buffile" ] || exit 0
        case "$kak_buffile" in \**\*) exit 0 ;; esac   # skip *scratch*, *debug*
        entry="$kak_buffile:$kak_cursor_line"
        # Drop any previous entry for the same file, prepend, then trim.
        printf 'set-option global kak_ide_jump_ring %s\n' "'$entry'"
        eval "set -- $kak_quoted_opt_kak_ide_jump_ring"
        n=1
        for e do
            [ "$n" -ge "$kak_opt_kak_ide_jump_ring_size" ] && break
            case "$e" in "${kak_buffile}:"*) continue ;; esac
            printf 'set-option -add global kak_ide_jump_ring %s\n' "'$e'"
            n=$((n + 1))
        done
    }
}

hook global WinDisplay .* kak-ide-jump-record

define-command kak-ide-picker-jumps -docstring %{
    kak-ide-picker-jumps: jump to a recently visited location
} %{
    kak-ide-picker-remember kak-ide-picker-jumps
    require-module fzf
    evaluate-commands %sh{
        eval "set -- $kak_quoted_opt_kak_ide_jump_ring"
        [ $# -gt 0 ] || { printf 'echo -markup %%{{Information}kak-ide: no locations recorded yet}\n'; exit 0; }
        list=$(for e do printf '%s\n' "$e"; done)
        printf "fzf -kak-cmd %%{evaluate-commands} -items-cmd %%{printf '%%s\\\\n' '%s'} -filter %%{sed -E 's|^(.*):([0-9]+)\$|edit -existing \"\\\\1\"; execute-keys \\\\2gvc|'} -fzf-args %%{--reverse}\n" \
            "$(printf '%s' "$list" | sed "s/'/'\\\\''/g")"
    }
}

# ─── Command palette ─────────────────────────────────────────────────────────
#
# Kakoune exposes no way to enumerate its commands: there is no %val for them,
# `debug` has no `commands` subcommand, and this build ships no doc pages. The
# palette therefore builds its own index by scraping `define-command` out of
# every .kak file that is actually loaded, and unions it with a static list of
# the C++ builtins (which are not defined in any .kak file). The index is cached
# because the scrape walks a few hundred files; refresh with
# `:kak-ide-palette-refresh` after installing a plugin.

declare-option -docstring "cache file for the command palette index" \
    str kak_ide_palette_cache "%val{config}/.kak-ide-palette"

declare-option -hidden str kak_ide_palette_builtins %{
add-highlighter alias arrange-buffers buffer buffer-next buffer-previous
change-directory colorscheme comment-block comment-line complete-command
debug declare-option declare-user-mode define-command delete-buffer
doc echo edit enter-user-mode evaluate-commands execute-keys fail
format-buffer format-selections git grep hook info kill map menu nop
on-key prompt provide-module quit remove-highlighter remove-hooks rename-buffer
rename-client rename-session require-module select set-face set-option
set-register source spell suggest-word try unalias unmap unset-option
update-option write write-all write-all-quit write-quit
}

define-command kak-ide-palette-refresh -docstring %{
    kak-ide-palette-refresh: rebuild the command palette index
} %{
    echo -markup "{Information}kak-ide: rebuilding palette index…"
    nop %sh{
        cache="$kak_opt_kak_ide_palette_cache"
        {
            # Builtins (not discoverable by scraping — they live in the C++ core).
            for c in $kak_opt_kak_ide_palette_builtins; do printf '%s\n' "$c"; done
            # Script-defined commands from everything that is actually loaded.
            grep -rhoE '^define-command +(-[a-z-]+ +)*[a-zA-Z][a-zA-Z0-9_-]*' \
                "$kak_runtime/rc" "$kak_config" 2>/dev/null |
                sed -E 's/^define-command +//; s/^(-[a-z-]+ +)*//' |
                grep -v '^-'
            # kakoune-lsp generates its commands at runtime rather than shipping
            # a .kak file, so ask the binary for them.
            command -v kak-lsp >/dev/null 2>&1 &&
                kak-lsp 2>/dev/null |
                grep -oE '^define-command +(-[a-z-]+ +)*[a-zA-Z][a-zA-Z0-9_-]*' |
                sed -E 's/^define-command +//; s/^(-[a-z-]+ +)*//' |
                grep -v '^-'
        } | sort -u | grep -vE '^(-|$)' > "$cache"
    }
    echo -markup "{Information}kak-ide: palette index rebuilt"
}

define-command kak-ide-picker-palette -docstring %{
    kak-ide-picker-palette: run any command (command palette)
} %{
    kak-ide-picker-remember kak-ide-picker-palette
    require-module fzf
    evaluate-commands %sh{
        cache="$kak_opt_kak_ide_palette_cache"
        [ -s "$cache" ] || printf 'kak-ide-palette-refresh\n'
        # -kak-cmd is the prompt, not the executor: land the choice in the `:`
        # prompt so arguments can still be typed, rather than firing blind.
        printf "fzf -kak-cmd %%{kak-ide-palette-run} -items-cmd %%{cat '%s'} -fzf-args %%{--reverse}\n" "$cache"
    }
}

define-command -hidden -params 1 kak-ide-palette-run %{
    prompt -init "%arg{1} " 'command: ' %{
        evaluate-commands %val{text}
    }
}

# ─── LSP-backed pickers ──────────────────────────────────────────────────────
#
# kakoune-lsp already provides these; wrapping them only registers them for
# last-picker recall and gives them names consistent with the rest.

define-command kak-ide-picker-symbols -docstring %{
    kak-ide-picker-symbols: symbols in the current document
} %{
    kak-ide-picker-remember kak-ide-picker-symbols
    lsp-document-symbol
}

define-command kak-ide-picker-symbols-workspace -docstring %{
    kak-ide-picker-symbols-workspace: symbols across the workspace
} %{
    kak-ide-picker-remember kak-ide-picker-symbols-workspace
    lsp-workspace-symbol-incr
}

define-command kak-ide-picker-diagnostics -docstring %{
    kak-ide-picker-diagnostics: diagnostics across the workspace
} %{
    kak-ide-picker-remember kak-ide-picker-diagnostics
    lsp-diagnostics
}
