# kak-ide — workspace trust
#
# Plan item 11 / Section 2.11. Opening a file from an untrusted directory
# should not silently start a language server: LSP config can name an
# arbitrary binary, and a repo-local `.eslintrc.js` / `biome.json` /
# `build.rs` is executable content authored by whoever wrote the repo.
#
# Trust is per project root and persistent. Nothing is prompted modally —
# an untrusted root simply does not get LSP, and says so in the status line.

declare-option -docstring "gate LSP startup behind a per-project trust decision" \
    bool kak_ide_trust_enable false

declare-option -docstring "file holding the list of trusted project roots" \
    str kak_ide_trust_file "%val{config}/kak-ide-trusted"

declare-option -docstring "whether the current buffer's project root is trusted" \
    bool kak_ide_trusted false

define-command -hidden kak-ide-trust-check %{
    evaluate-commands %sh{
        [ "$kak_opt_kak_ide_trust_enable" = true ] || {
            echo 'set-option buffer kak_ide_trusted true'; exit 0
        }
        root="$kak_opt_kak_ide_project_root"
        [ -n "$root" ] || { echo 'set-option buffer kak_ide_trusted false'; exit 0; }
        if [ -f "$kak_opt_kak_ide_trust_file" ] &&
           grep -qxF -- "$root" "$kak_opt_kak_ide_trust_file" 2>/dev/null; then
            echo 'set-option buffer kak_ide_trusted true'
        else
            echo 'set-option buffer kak_ide_trusted false'
        fi
    }
}

define-command kak-ide-trust -docstring %{
    kak-ide-trust: trust the current project root (starts LSP, persists)
} %{
    kak-ide-detect-root
    evaluate-commands %sh{
        root="$kak_opt_kak_ide_project_root"
        [ -n "$root" ] || { echo 'fail "kak-ide: no project root detected"'; exit 0; }
        mkdir -p "${kak_opt_kak_ide_trust_file%/*}" 2>/dev/null
        if ! grep -qxF -- "$root" "$kak_opt_kak_ide_trust_file" 2>/dev/null; then
            printf '%s\n' "$root" >> "$kak_opt_kak_ide_trust_file"
        fi
        printf 'set-option buffer kak_ide_trusted true\n'
        printf 'echo -markup %%{{Information}kak-ide: trusted %s}\n' "$root"
    }
    kak-ide-lsp-start-if-trusted
}

define-command kak-ide-untrust -docstring %{
    kak-ide-untrust: revoke trust for the current project root and stop its servers
} %{
    evaluate-commands %sh{
        root="$kak_opt_kak_ide_project_root"
        f="$kak_opt_kak_ide_trust_file"
        if [ -n "$root" ] && [ -f "$f" ]; then
            grep -vxF -- "$root" "$f" > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f"
        fi
        printf 'set-option buffer kak_ide_trusted false\n'
        printf 'echo -markup %%{{Information}kak-ide: revoked trust for %s}\n' "$root"
    }
    try %{ lsp-stop }
}

define-command kak-ide-trust-list -docstring %{
    kak-ide-trust-list: show every trusted project root
} %{
    evaluate-commands %sh{
        f="$kak_opt_kak_ide_trust_file"
        if [ -s "$f" ]; then
            printf 'info -title %%{trusted project roots} %%{%s}\n' "$(cat "$f")"
        else
            printf 'info -title %%{trusted project roots} %%{(none)}\n'
        fi
    }
}

define-command -hidden kak-ide-lsp-start-if-trusted %{
    evaluate-commands %sh{
        if [ "$kak_opt_kak_ide_trusted" = true ]; then
            echo 'try %{ lsp-enable-window }'
        else
            printf 'echo -markup %%{{Information}kak-ide: %s is untrusted — LSP off. :kak-ide-trust to enable}\n' \
                "${kak_opt_kak_ide_project_root##*/}"
        fi
    }
}
