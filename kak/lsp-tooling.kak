declare-option -docstring %{
    Файлы/каталоги, помечающие корень проекта, в порядке приоритета.
    Корень VCS всегда выигрывает.
} str-list web_root_markers \
    .git .hg .svn .jj .project-root \
    Cargo.toml package.json tsconfig.json jsconfig.json deno.json \
    go.mod pyproject.toml .luarc.json Makefile

declare-option -docstring "корень проекта текущего буфера" str web_project_root

declare-option -hidden str web_root_sh %{
    dir="${kak_buffile%/*}"
    [ -d "$dir" ] || dir="$PWD"
    root=$(cd "$dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
    if [ -z "$root" ]; then
        eval "set -- $kak_quoted_opt_web_root_markers"
        d="$dir"
        while [ -n "$d" ] && [ "$d" != "/" ]; do
            for m do
                if [ -e "$d/$m" ]; then root="$d"; break 2; fi
            done
            d="${d%/*}"
        done
    fi
    [ -n "$root" ] || root="$PWD"
}

define-command web-detect-root -docstring %{
    web-detect-root: определить и закешировать корень проекта
} %{
    set-option buffer web_project_root %sh{
        : "$kak_buffile" "$kak_quoted_opt_web_root_markers"
        eval "$kak_opt_web_root_sh"
        printf '%s' "$root"
    }
}

declare-option -docstring "форматтер буфера (biome|prettier|stylua|lsp|none)" \
    str web_formatter none

declare-option -docstring "линтер буфера (biome|eslint|lsp|none)" \
    str web_linter none

declare-option -docstring "разрешённая цепочка инструментов, для модлайна" \
    str web_tooling

declare-option -hidden str web_tool_resolve_sh %{
    web_bin() {
        if [ -x "$root/node_modules/.bin/$1" ]; then
            printf '%s' "$root/node_modules/.bin/$1"
        else
            command -v "$1" 2>/dev/null
        fi
    }
}

define-command -hidden web-detect-tooling %{
    web-detect-root
    evaluate-commands %sh{
        : "$kak_opt_filetype" "$kak_buffile"
        root="$kak_opt_web_project_root"
        [ -n "$root" ] || exit 0
        eval "$kak_opt_web_tool_resolve_sh"

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
            b=$(web_bin biome)
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
                p=$(web_bin prettier)
                [ -n "$p" ] && { formatter=prettier; fmt_bin="$p"; }
            fi
        fi

        [ "$formatter" = none ] && formatter=lsp
        [ "$linter"    = none ] && linter=lsp

        printf 'set-option buffer web_formatter %s\n' "$formatter"
        printf 'set-option buffer web_linter %s\n'    "$linter"
        printf 'set-option buffer web_tooling %%{fmt:%s lint:%s}\n' "$formatter" "$linter"

        shq() { printf "%s" "$1" | sed "s/'/'\\\\''/g"; }
        kkq() { printf "%s" "$1" | sed "s/'/''/g"; }
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
            printf 'set-option buffer web_formatter stylua\n'
            printf 'set-option buffer web_tooling %%{fmt:stylua lint:lua-ls}\n'
        else
            printf 'set-option buffer web_formatter lsp\n'
            printf 'set-option buffer web_tooling %%{fmt:lua-ls lint:lua-ls}\n'
        fi
        printf 'set-option buffer web_linter lsp\n'
    }
}

hook global BufSetOption filetype=(?:javascript|typescript|jsx|tsx|css|scss|less|json) %{
    web-detect-tooling
}

hook global BufCreate .* web-detect-root
hook global BufWritePost .* web-detect-root

define-command web-format -docstring %{
    web-format: форматировать буфер разрешённым форматтером (или LSP)
} %{
    evaluate-commands %sh{
        if [ -n "$kak_opt_formatcmd" ]; then
            echo 'format'
        else
            echo 'try %{ lsp-formatting-sync }'
        fi
    }
}

define-command web-tooling-info -docstring %{
    web-tooling-info: показать разрешённые форматтер/линтер
} %{
    evaluate-commands %sh{
        printf 'info -title %%{tooling} %%{root:      %s\nfiletype:  %s\nformatter: %s\nlinter:    %s\nformatcmd: %s}\n' \
            "$kak_opt_web_project_root" "$kak_opt_filetype" \
            "$kak_opt_web_formatter" "$kak_opt_web_linter" \
            "${kak_opt_formatcmd:-(language server)}"
    }
}

# kakoune-lsp рассылает codeAction/resolve всем серверам буфера и берёт первый
# ответ. biome отдаёт quickfix без `edit` — только `data`, которую нужно
# дорезолвить. Поэтому выбранный фикс biome уходит и в tsserver, тот его не
# узнаёт и возвращает пустое действие; kak-lsp превращает это в пустую команду
# и падает с "wrong argument count", а фикс молча теряется. Порядок серверов не
# помогает — победитель определяется внутренним id.
#
# Сужение lsp_servers до biome на время запроса замыкает и codeAction, и resolve
# на одном сервере. Меню асинхронное, колбэка завершения у kak-lsp нет, поэтому
# список восстанавливается лениво: следующий BufSetOption пересоберёт его, а сама
# команда каждый раз выводит нужный список заново.

define-command web-code-actions -docstring %{
    web-code-actions: code actions, на диагностике biome — только biome
} %{
    evaluate-commands %sh{
        : "$kak_opt_web_linter" "$kak_cursor_line" "$kak_quoted_opt_lsp_inlay_diagnostics"

        on_diagnostic=no
        if [ "$kak_opt_web_linter" = biome ]; then
            eval "set -- $kak_quoted_opt_lsp_inlay_diagnostics"
            shift
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

define-command web-fix-all -docstring %{
    web-fix-all: применить все автофиксы и организовать импорты
} %{
    try %{ lsp-code-actions-sync source.fixAll }
    try %{ lsp-code-actions-sync source.organizeImports }
}

define-command web-organize-imports -docstring %{
    web-organize-imports: организовать импорты
} %{
    lsp-code-actions-sync source.organizeImports
}
