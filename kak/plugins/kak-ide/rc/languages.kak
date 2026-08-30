
# ─── Filetype detection ───────────────────────────────────────────────────────

hook global BufCreate .*[.]jsx %{ set-option buffer filetype jsx }
hook global BufCreate .*[.]tsx %{ set-option buffer filetype tsx }
hook global BufCreate .*[.]es6 %{ set-option buffer filetype javascript }
hook global BufCreate .*[.]rockspec %{ set-option buffer filetype lua }

# ─── JSX / TSX: pieces Kakoune has no filetype module for ─────────────────────
#
# Kakoune folds .jsx/.tsx into javascript/typescript, but kak-tree-sitter picks
# its grammar from `filetype`, and the typescript queries cannot parse JSX — so
# these get filetypes of their own (set above). That means none of the builtin
# javascript/typescript hooks fire for them, and the indent hooks, comment
# tokens, highlighters and lsp_language_id all have to be re-supplied here.
#
# The highlighters only need a `ref` to the base language: JSX regions are
# installed into shared/javascript AND shared/typescript by
# init-javascript-filetype, so both already understand JSX.

hook global WinSetOption filetype=(jsx|tsx) %{
    require-module javascript

    hook window ModeChange pop:insert:.* -group "%val{hook_param_capture_1}-trim-indent" javascript-trim-indent
    hook window InsertChar .* -group "%val{hook_param_capture_1}-indent"  javascript-indent-on-char
    hook window InsertChar \n -group "%val{hook_param_capture_1}-insert"  javascript-insert-on-new-line
    hook window InsertChar \n -group "%val{hook_param_capture_1}-indent"  javascript-indent-on-new-line

    hook -once -always window WinSetOption filetype=.* "
        remove-hooks window %val{hook_param_capture_1}-.+
    "
}

hook global BufSetOption filetype=(?:jsx|tsx) %{
    set-option buffer comment_line '//'
    set-option buffer comment_block_begin '/*'
    set-option buffer comment_block_end '*/'
}

hook -group kak-ide-jsx-highlight global WinSetOption filetype=jsx %{
    require-module javascript
    add-highlighter window/jsx ref javascript
    hook -once -always window WinSetOption filetype=.* %{ try %{ remove-highlighter window/jsx } }
}

hook -group kak-ide-tsx-highlight global WinSetOption filetype=tsx %{
    require-module typescript
    add-highlighter window/tsx ref typescript
    hook -once -always window WinSetOption filetype=.* %{ try %{ remove-highlighter window/tsx } }
}

hook global BufSetOption filetype=jsx %{ set-option buffer lsp_language_id javascriptreact }
hook global BufSetOption filetype=tsx %{ set-option buffer lsp_language_id typescriptreact }

# ─── Indentation: 2 spaces across the board ──────────────────────────────────
#
# Kakoune ships rc/detection/editorconfig.kak, but it only defines an opt-in
# `editorconfig-load` command (no hook calls it, and it needs the editorconfig
# binary on PATH), so it cannot replace this default.

hook global BufSetOption filetype=(?:javascript|typescript|jsx|tsx|json|lua) %{
    set-option buffer tabstop 2
    set-option buffer indentwidth 2
}

# ─── Language servers ─────────────────────────────────────────────────────────

declare-option -docstring %{
    TypeScript language server: "auto", "vtsls", or "typescript-language-server".

    "auto" prefers vtsls when it is on PATH. vtsls vendors its own TypeScript,
    so it works in a project with no node_modules. typescript-language-server
    vendors none: without one it refuses to start, and that failure panics
    kak-lsp and disables LSP for the buffer — so it is only chosen when a
    TypeScript can actually be resolved for it.
} str kak_ide_ts_server auto

hook global BufSetOption filetype=(?:javascript|typescript|jsx|tsx) %{
    kak-ide-detect-root
    evaluate-commands %sh{
        : "$kak_opt_kak_ide_project_root" "$kak_opt_kak_ide_ts_server"
        root="$kak_opt_kak_ide_project_root"

        ts="$root/node_modules/typescript/lib/tsserver.js"
        [ -f "$ts" ] || ts="$HOME/.local/share/kak-ide/node_modules/typescript/lib/tsserver.js"
        [ -f "$ts" ] || ts=""

        server="$kak_opt_kak_ide_ts_server"
        if [ "$server" = auto ]; then
            if command -v vtsls >/dev/null 2>&1; then
                server=vtsls
            else
                server=typescript-language-server
            fi
        fi
        if [ "$server" = typescript-language-server ] && [ -z "$ts" ]; then
            command -v vtsls >/dev/null 2>&1 && server=vtsls
        fi

        printf 'set-option buffer lsp_servers %%{\n'
        printf '    [%s]\n' "$server"
        printf '%s\n' '    root_globs = ["package.json", "tsconfig.json", "jsconfig.json", ".git", ".hg"]'
        printf '%s\n' '    args = ["--stdio"]'
        printf '%s\n' '    settings_section = "_"'
        printf '    [%s.settings._]\n' "$server"
        printf '%s\n' '    hostInfo = "kak-ide"'
        if [ "$server" = typescript-language-server ] && [ -n "$ts" ]; then
            printf '    tsserver.path = "%s"\n' "$ts"
        fi
        printf '    [%s.settings]\n' "$server"
        if [ "$server" = vtsls ] && [ -d "$root/node_modules/typescript/lib" ]; then
            printf '    typescript.tsdk = "%s"\n' "$root/node_modules/typescript/lib"
        fi
        for lang in typescript javascript; do
            if [ "$server" = vtsls ]; then
                printf '    %s.inlayHints.enumMemberValues.enabled = true\n' "$lang"
                printf '    %s.inlayHints.functionLikeReturnTypes.enabled = true\n' "$lang"
                printf '    %s.inlayHints.parameterTypes.enabled = true\n' "$lang"
                printf '    %s.inlayHints.parameterNames.enabled = "all"\n' "$lang"
                printf '    %s.inlayHints.parameterNames.suppressWhenArgumentMatchesName = false\n' "$lang"
                printf '    %s.inlayHints.propertyDeclarationTypes.enabled = true\n' "$lang"
                printf '    %s.inlayHints.variableTypes.enabled = true\n' "$lang"
                printf '    %s.inlayHints.variableTypes.suppressWhenTypeMatchesName = false\n' "$lang"
            else
                printf '    %s.inlayHints.includeInlayEnumMemberValueHints = true\n' "$lang"
                printf '    %s.inlayHints.includeInlayFunctionLikeReturnTypeHints = true\n' "$lang"
                printf '    %s.inlayHints.includeInlayFunctionParameterTypeHints = true\n' "$lang"
                printf '    %s.inlayHints.includeInlayParameterNameHints = "all"\n' "$lang"
                printf '    %s.inlayHints.includeInlayParameterNameHintsWhenArgumentMatchesName = true\n' "$lang"
                printf '    %s.inlayHints.includeInlayPropertyDeclarationTypeHints = true\n' "$lang"
                printf '    %s.inlayHints.includeInlayVariableTypeHints = true\n' "$lang"
            fi
        done
        printf '%s\n' '}'
    }
}

hook global BufSetOption filetype=lua %{
    set-option buffer lsp_servers %{
        [lua-language-server]
        root_globs = [".luarc.json", ".luarc.jsonc", ".git", ".hg"]
        single_instance = false
        settings_section = "Lua"
        [lua-language-server.settings.Lua]
        hint.enable = true
        hint.arrayIndex = "Enable"
        hint.setType = true
        hint.paramName = "All"
        hint.paramType = true
        hint.await = true
    }
}

# ─── Tailwind CSS ────────────────────────────────────────────────────────────
#
# tailwindcss-language-server supplies class-name completion, colour swatches
# and hover for the utility classes. It is additive: the buffer already has
# vtsls (jsx/tsx) or vscode-css-language-server (css), and biome may attach as
# a linter, so this uses `set-option -add` -- a plain `set-option` would drop
# whichever server got there first.
#
# It only attaches when the project actually uses Tailwind. The v4 setup keeps
# no JS config at all (`@import "tailwindcss"` in the stylesheet), so a
# tailwind.config.* probe alone would silently skip v4 projects; the dependency
# in package.json is what both versions have in common.
#
# `settings_section` is load-bearing. The server asks for its configuration via
# workspace/configuration and publishes nothing until that request is answered
# with a non-empty tailwindCSS section -- without it the server starts, reports
# healthy, and returns zero completions.
#
# includeLanguages maps the filetypes Kakoune reports to the ones the server
# understands, otherwise it ignores jsx/tsx buffers entirely.

declare-option -docstring %{
    Attach tailwindcss-language-server when the project depends on tailwindcss.
} bool kak_ide_tailwind true

hook global BufSetOption filetype=(?:jsx|tsx|javascript|typescript|css|scss|less) %{
    kak-ide-detect-root
    evaluate-commands %sh{
        : "$kak_opt_kak_ide_project_root" "$kak_opt_kak_ide_tailwind"
        [ "$kak_opt_kak_ide_tailwind" = true ] || exit 0
        command -v tailwindcss-language-server >/dev/null 2>&1 || exit 0

        root="$kak_opt_kak_ide_project_root"
        [ -n "$root" ] || exit 0

        found=no
        for c in tailwind.config.js tailwind.config.cjs tailwind.config.mjs \
                 tailwind.config.ts tailwind.config.cts tailwind.config.mts; do
            [ -f "$root/$c" ] && { found=yes; break; }
        done
        if [ "$found" = no ] && [ -f "$root/package.json" ] &&
           grep -q '"tailwindcss"' "$root/package.json" 2>/dev/null; then
            found=yes
        fi
        [ "$found" = yes ] || exit 0

        cat <<'TOML'
set-option -add buffer lsp_servers %{

[tailwindcss-language-server]
args = ["--stdio"]
root_globs = ["tailwind.config.js", "tailwind.config.cjs", "tailwind.config.mjs", "tailwind.config.ts", "package.json", ".git"]
settings_section = "tailwindCSS"
[tailwindcss-language-server.settings.editor]
tabSize = 2
[tailwindcss-language-server.settings.tailwindCSS]
validate = true
classAttributes = ["class", "className", "ngClass", "class:list"]
[tailwindcss-language-server.settings.tailwindCSS.includeLanguages]
jsx = "javascriptreact"
tsx = "typescriptreact"
[tailwindcss-language-server.settings.tailwindCSS.lint]
cssConflict = "warning"
invalidApply = "error"
invalidConfigPath = "error"
invalidScreen = "error"
invalidTailwindDirective = "error"
invalidVariant = "error"
recommendedVariantOrder = "warning"
unknownAtRules = "warning"
}
TOML
    }
}
