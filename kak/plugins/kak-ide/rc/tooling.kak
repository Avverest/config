# kak-ide — per-project formatter / linter detection  (plan Section 6.1)
#
# Helix deliberately ships no Prettier/ESLint/Biome wiring for JS/TS. The plan
# asks kak-ide to opt in by default, because format-on-save is the baseline
# expectation in React/TS work. Detection runs once per project root and is
# cached in buffer options.
#
# Deviation from the plan, forced by the toolchain: Section 6.1 asks for Biome
# and ESLint to be attached with Helix's `only-features`/`except-features`
# scoping. kakoune-lsp 21 has no such key — see AUDIT.md Finding 2. Servers are
# therefore attached unscoped (diagnostics and code actions from several servers
# merge, which is what we want anyway) and FORMATTING is scoped the way
# kakoune-lsp actually supports it: an explicit `formatcmd`, so the chosen
# formatter is unambiguous and tsserver's built-in formatter never competes.

declare-option -docstring "format the buffer on write when a formatter is resolved" \
    bool kak_ide_format_on_save true

declare-option -docstring "formatter resolved for this buffer (biome|prettier|lsp|none)" \
    str kak_ide_formatter none

declare-option -docstring "linter resolved for this buffer (biome|eslint|lsp|none)" \
    str kak_ide_linter none

declare-option -docstring "human-readable resolved tool chain, for the modeline" \
    str kak_ide_tooling

# Shared resolver. Prefers a project-local node_modules/.bin over a global
# install, so a repo pinning its own Prettier gets that Prettier.
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

        # What each tool actually covers (plan §6.1 item 4):
        #   Biome     — formats JS/TS/JSX/TSX/JSON and (since 1.8) CSS.
        #               Lints JS/TS/JSX/TSX/JSON only.
        #   ESLint    — lints the JS family only.
        #   Prettier  — formats everything here.
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

        # 1. Biome replaces both Prettier and ESLint where it has coverage.
        if [ "$has_biome_cfg" = yes ]; then
            b=$(kak_ide_bin biome)
            if [ -n "$b" ]; then
                [ "$biome_fmt" = yes ]  && { formatter=biome; fmt_bin="$b"; }
                [ "$biome_lint" = yes ] && { linter=biome; lint_attach=biome; }
            fi
        fi

        # 2. Otherwise ESLint supplies lint diagnostics + quick fixes.
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

        # 3. Formatting precedence, independent of the lint choice:
        #    Biome (settled above) > Prettier > the language server's formatter.
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

        # formatcmd — a stdin filter, which is exactly what Kakoune's `format` wants.
        #
        # Kakoune runs this via `eval "$kak_opt_formatcmd"` in a POSIX shell, so
        # the value must be READY-TO-RUN SHELL. A `%val{buffile}` written inside
        # a %{...} option value is never expanded (raw string) and reaches the
        # formatter as the literal seven characters "%val{buffile}" — which is
        # why a formatter configured that way silently does nothing. Substitute
        # the real path here and quote both halves for the shell.
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
        printf "set-option buffer formatcmd '%s'\n" "$(kkq "$cmd")"

        # Attach the lint server alongside tsserver.
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

# Lua: kak-ide configures it, but §6.1's JS toolchain does not apply. Report
# honestly rather than leaving the default "none", which reads like a failure.
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

# Run detection for the languages Section 6.1 covers. This must be registered
# after languages.kak's `lsp_servers` hooks so the append lands on top of them.
hook global BufSetOption filetype=(?:javascript|typescript|jsx|tsx|css|scss|less|json) %{
    kak-ide-detect-tooling
}

# ─── Format on save ──────────────────────────────────────────────────────────
#
# `formatcmd` is used when one was resolved; otherwise fall back to the language
# server's formatter. A formatter that errors (syntax error mid-edit) leaves the
# buffer untouched — Kakoune's `format` discards a failed filter's output.

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

hook global BufSetOption filetype=(?:javascript|typescript|jsx|tsx|css|scss|less|json|lua) %{
    hook buffer -group kak-ide-format BufWritePre .* %{
        evaluate-commands %sh{
            [ "$kak_opt_kak_ide_format_on_save" = true ] && echo 'kak-ide-format'
        }
    }
}

define-command kak-ide-format-on-save-toggle -docstring %{
    kak-ide-format-on-save-toggle: turn format-on-save on or off for this session
} %{
    evaluate-commands %sh{
        if [ "$kak_opt_kak_ide_format_on_save" = true ]; then
            echo 'set-option global kak_ide_format_on_save false'
            echo 'echo -markup %{{Information}kak-ide: format-on-save OFF}'
        else
            echo 'set-option global kak_ide_format_on_save true'
            echo 'echo -markup %{{Information}kak-ide: format-on-save ON}'
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
