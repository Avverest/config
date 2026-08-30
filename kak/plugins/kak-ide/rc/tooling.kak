
declare-option -docstring "formatter resolved for this buffer (biome|prettier|lsp|none)" \
    str kak_ide_formatter none

declare-option -docstring "linter resolved for this buffer (biome|eslint|lsp|none)" \
    str kak_ide_linter none

declare-option -docstring "human-readable resolved tool chain, for the modeline" \
    str kak_ide_tooling

declare-option -hidden str kak_ide_tool_resolve_sh %{
    kak_ide_bin() {
        if [ -x "$root/node_modules/.bin/$1" ]; then
            printf '%s' "$root/node_modules/.bin/$1"
        else
            command -v "$1" 2>/dev/null
        fi
    }
}

define-command -hidden kak-ide-detect-tooling %{
    kak-ide-detect-root
    evaluate-commands %sh{
        : "$kak_opt_filetype" "$kak_buffile"
        root="$kak_opt_kak_ide_project_root"
        [ -n "$root" ] || exit 0
        eval "$kak_opt_kak_ide_tool_resolve_sh"

        case "$kak_opt_filetype" in
            javascript|typescript|jsx|tsx|json)
                biome_fmt=yes; biome_lint=yes; eslint_ok=yes ;;
            css|scss|less)
                biome_fmt=yes; biome_lint=no;  eslint_ok=no  ;;
            *)
                biome_fmt=no;  biome_lint=no;  eslint_ok=no  ;;
        esac

        formatter=none; linter=none; fmt_bin=''; lint_attach=''
        has_biome_cfg=no
        { [ -f "$root/biome.json" ] || [ -f "$root/biome.jsonc" ]; } && has_biome_cfg=yes

        if [ "$has_biome_cfg" = yes ]; then
            b=$(kak_ide_bin biome)
            if [ -n "$b" ]; then
                [ "$biome_fmt" = yes ]  && { formatter=biome; fmt_bin="$b"; }
                [ "$biome_lint" = yes ] && { linter=biome; lint_attach=biome; }
            fi
        fi

        if [ "$linter" = none ] && [ "$eslint_ok" = yes ]; then
            for c in .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml \
                     eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts; do
                if [ -f "$root/$c" ]; then linter=eslint; break; fi
            done
            if [ "$linter" = none ] && [ -f "$root/package.json" ] &&
               grep -q '"eslintConfig"' "$root/package.json" 2>/dev/null; then
                linter=eslint
            fi
            [ "$linter" = eslint ] && lint_attach=eslint
        fi

        if [ "$formatter" = none ]; then
            has_prettier=no
            for c in .prettierrc .prettierrc.json .prettierrc.yml .prettierrc.yaml \
                     .prettierrc.json5 .prettierrc.js .prettierrc.cjs .prettierrc.mjs \
                     .prettierrc.toml prettier.config.js prettier.config.cjs prettier.config.mjs; do
                if [ -f "$root/$c" ]; then has_prettier=yes; break; fi
            done
            if [ "$has_prettier" = no ] && [ -f "$root/package.json" ] &&
               grep -q '"prettier"' "$root/package.json" 2>/dev/null; then
                has_prettier=yes
            fi
            if [ "$has_prettier" = yes ]; then
                p=$(kak_ide_bin prettier)
                [ -n "$p" ] && { formatter=prettier; fmt_bin="$p"; }
            fi
        fi

        [ "$formatter" = none ] && formatter=lsp
        [ "$linter"    = none ] && linter=lsp

        printf 'set-option buffer kak_ide_formatter %s\n' "$formatter"
        printf 'set-option buffer kak_ide_linter %s\n'    "$linter"
        printf 'set-option buffer kak_ide_tooling %%{fmt:%s lint:%s}\n' "$formatter" "$linter"

        shq() { printf "%s" "$1" | sed "s/'/'\\\\''/g"; }   # -> shell '...'
        kkq() { printf "%s" "$1" | sed "s/'/''/g"; }         # -> Kakoune '...'
        case "$formatter" in
            biome)
                cmd="'$(shq "$fmt_bin")' format --stdin-file-path='$(shq "$kak_buffile")'" ;;
            prettier)
                cmd="'$(shq "$fmt_bin")' --stdin-filepath '$(shq "$kak_buffile")'" ;;
            *)
                cmd="" ;;
        esac
        if [ -n "$cmd" ]; then
            printf "set-option buffer formatcmd '%s'\n" "$(kkq "$cmd")"
        fi

        case "$lint_attach" in
            biome)
                cat <<'TOML'
set-option -add buffer lsp_servers %{

[biome]
command = "biome"
args = ["lsp-proxy"]
root_globs = ["biome.json", "biome.jsonc"]
}
TOML
                ;;
            eslint)
                cat <<'TOML'
set-option -add buffer lsp_servers %{

[eslint-language-server]
command = "vscode-eslint-language-server"
args = ["--stdio"]
root_globs = [".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json", ".eslintrc.yml", "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs", "package.json"]
workaround_eslint = true
settings_section = "eslint"
[eslint-language-server.settings.eslint]
validate = "on"
run = "onType"
quiet = false
rulesCustomizations = []
format = { enable = false }
problems = { shortenToSingleLine = false }
codeAction.disableRuleComment = { enable = true, location = "separateLine" }
codeAction.showDocumentation = { enable = true }
}
TOML
                ;;
        esac
    }
}

hook global BufSetOption filetype=lua %{
    evaluate-commands %sh{
        if command -v stylua >/dev/null 2>&1; then
            printf 'set-option buffer kak_ide_formatter stylua\n'
            printf 'set-option buffer kak_ide_tooling %%{fmt:stylua lint:lua-ls}\n'
        else
            printf 'set-option buffer kak_ide_formatter lsp\n'
            printf 'set-option buffer kak_ide_tooling %%{fmt:lua-ls lint:lua-ls}\n'
        fi
        printf 'set-option buffer kak_ide_linter lsp\n'
    }
}

hook global BufSetOption filetype=(?:javascript|typescript|jsx|tsx|css|scss|less|json) %{
    kak-ide-detect-tooling
}

# ─── Format on demand ────────────────────────────────────────────────────────
#
# Formatting is explicit: nothing runs on write. The resolver above still picks
# biome/prettier/stylua per project and leaves it in `formatcmd`, so the command
# below reformats with whatever the project actually uses, falling back to the
# language server when no external formatter resolved.

define-command kak-ide-format -docstring %{
    kak-ide-format: format the buffer with the resolved formatter (or the LSP)
} %{
    evaluate-commands %sh{
        if [ -n "$kak_opt_formatcmd" ]; then
            echo 'format'
        else
            echo 'try %{ lsp-formatting-sync }'
        fi
    }
}

define-command kak-ide-tooling-info -docstring %{
    kak-ide-tooling-info: show which formatter/linter resolved for this buffer
} %{
    evaluate-commands %sh{
        printf 'info -title %%{kak-ide tooling} %%{root:      %s\nfiletype:  %s\nformatter: %s\nlinter:    %s\nformatcmd: %s}\n' \
            "$kak_opt_kak_ide_project_root" "$kak_opt_filetype" \
            "$kak_opt_kak_ide_formatter" "$kak_opt_kak_ide_linter" \
            "${kak_opt_formatcmd:-(language server)}"
    }
}

# ─── Code actions with biome attached ────────────────────────────────────────
#
# kakoune-lsp resolves a code action by broadcasting codeAction/resolve to
# *every* server on the buffer and taking whichever answers first
# (RequestParams::All + results.first() in code_action.rs). It tracks which
# server owns an action while building the menu, but drops that identity before
# resolving.
#
# biome returns its quickfixes with no `edit` -- only `data`, to be filled in by
# codeAction/resolve. So picking a biome fix sends biome's action to vtsls too;
# vtsls does not recognise it and echoes it back with neither `edit` nor
# `command`. kak-lsp turns that empty action into an empty editor command and
# sends a bare `evaluate-commands -client <c> -verbatim --`, which fails with
#
#     1:1: 'evaluate-commands': wrong argument count
#
# and the fix is silently lost. Whether the good reply or the useless one wins
# is decided by internal server id, so listing biome first does not help.
#
# Restricting lsp_servers to biome for the duration of the request scopes both
# the codeAction and its resolve to biome (kak-lsp reads meta.servers from this
# option per request), so the round-trip stays within one server.
#
# The menu is asynchronous and kak-lsp offers no completion callback, so the
# full list cannot be restored when the action finishes -- a NormalIdle hook
# fires while the menu is still open and would put vtsls back before the
# selection is resolved. Instead the list is restored lazily: on the next
# BufSetOption (buffer reload, filetype change) the resolver rebuilds it from
# scratch, and kak-ide-code-actions itself re-derives the scoped list on every
# call, so a stale narrow list is never observable outside a code action.

define-command kak-ide-code-actions -docstring %{
    kak-ide-code-actions: code actions, scoped to biome on a biome diagnostic
} %{
    evaluate-commands %sh{
        : "$kak_opt_kak_ide_linter" "$kak_cursor_line" "$kak_quoted_opt_lsp_inlay_diagnostics"

        # Only narrow when the cursor is actually on a line biome flagged.
        # Anywhere else the full server list stays in place, so vtsls keeps
        # offering renames, extractions and organize-imports as before.
        on_diagnostic=no
        if [ "$kak_opt_kak_ide_linter" = biome ]; then
            eval "set -- $kak_quoted_opt_lsp_inlay_diagnostics"
            shift   # timestamp
            for spec; do
                [ "${spec%%|*}" = "$kak_cursor_line" ] && { on_diagnostic=yes; break; }
            done
        fi

        if [ "$on_diagnostic" = no ]; then
            echo 'lsp-code-actions'
            exit 0
        fi

        cat <<'SCOPED'
set-option buffer lsp_servers %{
[biome]
command = "biome"
args = ["lsp-proxy"]
root_globs = ["biome.json", "biome.jsonc"]
}
lsp-code-actions
SCOPED
    }
}
