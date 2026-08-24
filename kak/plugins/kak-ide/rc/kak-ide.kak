# kak-ide — entry point
#
# An IDE layer for Kakoune, built to the requirements in KAKOUNE-PARITY-PLAN.md.
# It sits ON TOP OF kakoune-lsp and kak-tree-sitter rather than replacing them,
# and adds only what neither provides.
#
# Load it from kakrc with a single line, AFTER `evaluate-commands %sh{ kak-lsp }`:
#
#     source "%val{config}/plugins/kak-ide/rc/kak-ide.kak"
#
# Module load order is load-bearing:
#   project    root detection — every other module resolves paths against it
#   languages  filetype/indent/comment/server config for JS/TS/JSX/TSX and Lua
#   tooling    per-project Biome/ESLint/Prettier detection; appends to the above
#   splits     tmux-backed window splits + focus movement
#   keymap     bindings for tree-sitter and git, plus the `,` leader additions

declare-option -docstring "kak-ide version" str kak_ide_version "0.1.0-phase1"

evaluate-commands %sh{
    dir="${kak_source%/*}"
    for m in project languages tooling splits keymap; do
        printf 'source "%s/%s.kak"\n' "$dir" "$m"
    done
}

# ─── Startup ─────────────────────────────────────────────────────────────────
#
# Resolve the project root, then start the language server. `lsp-enable-window`
# is per-window rather than the global `lsp-enable` so a buffer with no server
# configured for its filetype simply gets nothing; `try` because it also fails
# when kak-lsp is not installed at all.

hook global WinCreate .* %{
    kak-ide-detect-root
    try %{ lsp-enable-window }
}

# Surface the resolved tool chain (plan §6.1 item 6) so a project with
# conflicting configs cannot silently pick a formatter behind your back.
define-command kak-ide-modeline-enable -docstring %{
    kak-ide-modeline-enable: show the resolved formatter/linter in the modeline
} %{
    set-option global modelinefmt "%opt{kak_ide_tooling} %opt{modelinefmt}"
}

define-command kak-ide-status -docstring %{
    kak-ide-status: report what kak-ide resolved for the current buffer
} %{
    evaluate-commands %sh{
        printf 'info -title %%{kak-ide %s} %%{project:   %s\nfiletype:  %s\nlanguage:  %s\nformatter: %s\nlinter:    %s}\n' \
            "$kak_opt_kak_ide_version" \
            "${kak_opt_kak_ide_project_root:-(none)}" \
            "${kak_opt_filetype:-(none)}" \
            "${kak_opt_lsp_language_id:-(none)}" \
            "$kak_opt_kak_ide_formatter" \
            "$kak_opt_kak_ide_linter"
    }
}
