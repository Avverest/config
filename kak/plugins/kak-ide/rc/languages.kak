# kak-ide — unified language configuration
#
# Plan Section 6 / gap #12: one source of truth for the seven target languages
# (Rust, TypeScript, JavaScript, JSX, TSX, HTML, CSS, Lua), covering filetype
# detection, indent width, comment tokens, language servers and their settings.
#
# Layering note: kakoune-lsp 21 ships sane defaults for all of these via
# `lsp-load-default-config`. Setting `lsp_servers` from a BufSetOption hook
# replaces that default wholesale, so each block below is written as a COMPLETE
# config — upstream's defaults plus the plan's settings — never a fragment.

# ─── Filetype detection ───────────────────────────────────────────────────────
#
# Kakoune already maps .js/.jsx/.mjs/.cjs -> javascript and .ts/.tsx/.mts/.cts
# -> typescript. That is wrong for the React dialects in one specific way:
# kak-tree-sitter selects its grammar and query set from `filetype`, and the
# `typescript` query set cannot parse JSX. Give .jsx/.tsx their own filetypes so
# tree-sitter picks the jsx/tsx queries, then re-supply the pieces Kakoune only
# provides for javascript/typescript (indent, comments, languageId) below.
#
# These hooks are registered after Kakoune's own, so they win.

hook global BufCreate .*[.]jsx %{ set-option buffer filetype jsx }
hook global BufCreate .*[.]tsx %{ set-option buffer filetype tsx }
hook global BufCreate .*[.]es6 %{ set-option buffer filetype javascript }
hook global BufCreate .*[.]rockspec %{ set-option buffer filetype lua }

# ─── JSX / TSX: pieces Kakoune has no filetype module for ─────────────────────

# Indentation: reuse the javascript module's commands verbatim — they are
# brace/paren driven and handle JSX fine.
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

# Comment tokens: rc/tools/comment.kak keys these by filetype and knows nothing
# about jsx/tsx, so they would otherwise fall back to '#'.
hook global BufSetOption filetype=(?:jsx|tsx) %{
    set-option buffer comment_line '//'
    set-option buffer comment_block_begin '/*'
    set-option buffer comment_block_end '*/'
}

# Static-highlighter fallback. jsx/tsx are filetypes Kakoune does not ship, so
# without this they render completely unhighlighted whenever kak-tree-sitter is
# not running (not installed, daemon down, grammar not yet synced). Tree-sitter
# replaces this layer when it attaches — kak-tree-sitter removes the
# `window/<filetype>` highlighter by default, which is exactly what these are
# named.
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

# languageId: tsserver needs the React dialect names, not our filetype names.
hook global BufSetOption filetype=jsx %{ set-option buffer lsp_language_id javascriptreact }
hook global BufSetOption filetype=tsx %{ set-option buffer lsp_language_id typescriptreact }

# ─── Indentation: 2 spaces across the board ──────────────────────────────────

hook global BufSetOption filetype=(?:javascript|typescript|jsx|tsx|json|lua) %{
    set-option buffer tabstop 2
    set-option buffer indentwidth 2
}

# ─── Language servers ─────────────────────────────────────────────────────────


# TypeScript / JavaScript / JSX / TSX.
# Lint and format servers are NOT declared here — `tooling.kak` appends Biome or
# ESLint per project once it has seen what the project actually uses (§6.1).

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

        # A TypeScript for typescript-language-server, which ships none:
        # the project's own first, so each project is checked by the version it
        # pins, then the copy kak-ide keeps under ~/.local/share/kak-ide.
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
        # Never hand kak-lsp a tsserver-less typescript-language-server.
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
        # vtsls defaults to its own vendored TypeScript. Point it at the
        # project's copy when there is one, so a repo pinned to an older
        # TypeScript is checked by that version rather than vtsls's.
        # (typescript-language-server finds the workspace copy by itself.)
        if [ "$server" = vtsls ] && [ -d "$root/node_modules/typescript/lib" ]; then
            printf '    typescript.tsdk = "%s"\n' "$root/node_modules/typescript/lib"
        fi
        # Inlay hints. The two servers spell these differently: tsserver's LSP
        # wrapper uses the includeInlay* flags, vtsls uses VS Code's own
        # inlayHints.* tree (it is the VS Code TS extension behind an LSP).
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


# Lua — hint settings transcribed from plan Section 6.
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
