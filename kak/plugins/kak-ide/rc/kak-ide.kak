declare-option -docstring "kak-ide version" str kak_ide_version "0.1.0-phase1"

evaluate-commands %sh{
    dir="${kak_source%/*}"
    for m in project mux languages tooling diagnostics splits files surround pairs cursor jump keymap; do
        printf 'source "%s/%s.kak"\n' "$dir" "$m"
    done
}

# ─── Startup ─────────────────────────────────────────────────────────────────

hook global WinCreate .* %{
    kak-ide-detect-root
    try %{ lsp-enable-window }
}

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
