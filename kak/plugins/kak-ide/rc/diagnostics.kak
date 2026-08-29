
# ─── Faces ───────────────────────────────────────────────────────────────────
#
# kak-lsp defaults these to `red`/`yellow` — a foreground on the offending text
# itself, which overrides syntax and tree-sitter highlighting. Kakoune's face
# format is [fg][,bg[,underline_color]][+attrs], so an independent underline
# colour plus `c` (curly) marks the range without touching its colours.
#
# Colours are catppuccin_latte literals rather than %opt{red}: the palette
# options are declared inside the colorscheme and only exist while it is
# active, and this file loads before `colorscheme` runs.

set-face global DiagnosticError   default,default,rgb:d20f39+c
set-face global DiagnosticWarning default,default,rgb:df8e1d+c
set-face global DiagnosticInfo    default,default,rgb:1e66f5+c
set-face global DiagnosticHint    default,default,rgb:6c6f85+c

# The inlay faces default to inheriting Diagnostic*, which above carries no
# foreground at all — the end-of-line text would come out the colour of
# ordinary code. They get their own visible foreground instead; `d` (dim) keeps
# the annotation from reading as source.

set-face global InlayDiagnosticError   rgb:d20f39+d
set-face global InlayDiagnosticWarning rgb:df8e1d+d
set-face global InlayDiagnosticInfo    rgb:1e66f5+d
set-face global InlayDiagnosticHint    rgb:6c6f85+d

set-option global lsp_diagnostic_line_error_sign   '●'
set-option global lsp_diagnostic_line_warning_sign '▲'
set-option global lsp_diagnostic_line_info_sign    '■'
set-option global lsp_diagnostic_line_hint_sign    '▪'

declare-option -docstring "show diagnostic text at the end of the offending line" \
    bool kak_ide_inlay_diagnostics true

declare-option -docstring "show the diagnostic under the cursor in the status line on idle" \
    bool kak_ide_auto_hover true

# ─── Diagnostics in the status line, never over the code ─────────────────────
#
# kak-lsp renders hover through `info`, which draws a box over the buffer. With
# or without `-anchor` it lands on top of the text being edited, so on a long
# message the offending code disappears behind the very thing describing it.
#
# The message text is already available without any request: kak-lsp keeps it
# in lsp_inlay_diagnostics, the line-specs the end-of-line inlay highlighter
# renders from. Each entry is `<line>|<text>`, the text carrying its own
# `{InlayDiagnosticError}`-style markup face. Echoing that entry for the cursor
# line puts the diagnostic in the status line, where nothing covers the buffer.
#
# Types stay available on demand via `,lh` (lsp-hover) and `,lH` (scratch
# buffer), both of which are explicit and therefore not in the way.

define-command -hidden kak-ide-echo-diagnostic %{
    evaluate-commands %sh{
        eval "set -- $kak_quoted_opt_lsp_inlay_diagnostics"
        shift   # timestamp
        for spec; do
            [ "${spec%%|*}" = "$kak_cursor_line" ] || continue
            text=$(printf '%s' "${spec#*|}" | tr '\n' ' ')
            printf "echo -markup '%s'" "$(printf '%s' "$text" | sed "s/'/''/g")"
            exit
        done
        echo 'echo'
    }
}

define-command kak-ide-auto-hover-enable -docstring %{
    kak-ide-auto-hover-enable: show the diagnostic under the cursor in the status line
} %{
    remove-hooks global kak-ide-auto-hover
    lsp-auto-hover-disable
    hook -group kak-ide-auto-hover global NormalIdle .* %{
        kak-ide-echo-diagnostic
    }
}

define-command kak-ide-auto-hover-disable -docstring %{
    kak-ide-auto-hover-disable: stop showing diagnostics in the status line on idle
} %{
    remove-hooks global kak-ide-auto-hover
}

define-command kak-ide-diagnostics-enable -docstring %{
    kak-ide-diagnostics-enable: show diagnostic text inline and in the status line

    kak-lsp's own lsp-enable already installs the range highlighting and the
    gutter flags; what it leaves off is the message text. This adds the
    end-of-line inlay and the idle status-line echo, neither of which covers
    the buffer the way an info box does.
} %{
    try %{
        set-option global lsp_hover_max_info_lines 10
        set-option global lsp_hover_max_diagnostic_lines 20

        lsp-inlay-diagnostics-enable global
        kak-ide-auto-hover-enable

        map global lsp I ': kak-ide-inlay-diagnostics-toggle<ret>' -docstring 'toggle inline error text'
        map global lsp D ': kak-ide-auto-hover-toggle<ret>'        -docstring 'toggle status-line diagnostics'

        echo -markup "{Information}kak-ide: diagnostics inline + status line (,lI / ,lD to toggle)"
    }
}

define-command kak-ide-inlay-diagnostics-toggle -docstring %{
    kak-ide-inlay-diagnostics-toggle: show or hide diagnostic text at end of line
} %{
    evaluate-commands %sh{
        if [ "$kak_opt_kak_ide_inlay_diagnostics" = true ]; then
            echo 'lsp-inlay-diagnostics-disable global'
            echo 'set-option global kak_ide_inlay_diagnostics false'
            echo 'echo -markup %{{Information}kak-ide: inline diagnostic text OFF}'
        else
            echo 'lsp-inlay-diagnostics-enable global'
            echo 'set-option global kak_ide_inlay_diagnostics true'
            echo 'echo -markup %{{Information}kak-ide: inline diagnostic text ON}'
        fi
    }
}

define-command kak-ide-auto-hover-toggle -docstring %{
    kak-ide-auto-hover-toggle: turn the idle status-line diagnostic on or off
} %{
    evaluate-commands %sh{
        if [ "$kak_opt_kak_ide_auto_hover" = true ]; then
            echo 'kak-ide-auto-hover-disable'
            echo 'set-option global kak_ide_auto_hover false'
            echo 'echo -markup %{{Information}kak-ide: status-line diagnostics OFF}'
        else
            echo 'kak-ide-auto-hover-enable'
            echo 'set-option global kak_ide_auto_hover true'
            echo 'echo -markup %{{Information}kak-ide: status-line diagnostics ON}'
        fi
    }
}
