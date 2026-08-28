
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

declare-option -docstring "pop up hover info (diagnostics and types) on idle" \
    bool kak_ide_auto_hover true

# ─── Hover only where there is a diagnostic ──────────────────────────────────
#
# kak-lsp's own lsp-auto-hover-enable fires `lsp-hover` on every NormalIdle,
# anywhere in the buffer. On a TSX prop that means vtsls dumps the whole
# inferred type over the code whenever the cursor pauses — the popup competes
# with what you are reading instead of telling you about a problem.
#
# This wraps it: same idle trigger, but the hover request is only sent when the
# cursor actually sits inside a diagnostic range. Types stay available on
# demand via `,lh`.
#
# lsp_inline_diagnostics is a range-specs whose entries are
# `<line>.<col>,<line>.<col>|<FaceName>` (the first field is the timestamp, so
# it is skipped). Only the line is compared: a column test would leave the
# popup flickering on and off as the cursor moves along the underlined text.

define-command -hidden kak-ide-hover-if-diagnostic %{
    evaluate-commands %sh{
        eval "set -- $kak_quoted_opt_lsp_inline_diagnostics"
        shift   # timestamp
        cursor_line=${kak_cursor_line}
        for range; do
            start=${range%%,*}
            start_line=${start%%.*}
            end=${range#*,}
            end_line=${end%%.*}
            if [ "$cursor_line" -ge "$start_line" ] && [ "$cursor_line" -le "$end_line" ]; then
                echo 'try lsp-hover'
                exit
            fi
        done
    }
}

define-command kak-ide-auto-hover-enable -docstring %{
    kak-ide-auto-hover-enable: pop up hover info on idle, but only on diagnostics
} %{
    remove-hooks global kak-ide-auto-hover
    lsp-auto-hover-disable
    hook -group kak-ide-auto-hover global NormalIdle .* %{
        lsp-check-auto-hover %{ kak-ide-hover-if-diagnostic }
    }
}

define-command kak-ide-auto-hover-disable -docstring %{
    kak-ide-auto-hover-disable: stop popping up hover info on idle
} %{
    remove-hooks global kak-ide-auto-hover
}

define-command kak-ide-diagnostics-enable -docstring %{
    kak-ide-diagnostics-enable: show diagnostic text inline and on hover

    kak-lsp's own lsp-enable already installs the range highlighting and the
    gutter flags; what it leaves off is the message text. This adds the
    end-of-line inlay and the idle hover box, and trims the hover to keep it
    about the error rather than a wall of inferred types.
} %{
    try %{
        set-option global lsp_hover_max_info_lines 10
        set-option global lsp_hover_max_diagnostic_lines 20

        lsp-inlay-diagnostics-enable global
        kak-ide-auto-hover-enable

        map global lsp I ': kak-ide-inlay-diagnostics-toggle<ret>' -docstring 'toggle inline error text'
        map global lsp D ': kak-ide-auto-hover-toggle<ret>'        -docstring 'toggle auto hover popup'

        echo -markup "{Information}kak-ide: diagnostics inline + on hover (,lI / ,lD to toggle)"
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
    kak-ide-auto-hover-toggle: turn the idle hover popup on or off
} %{
    evaluate-commands %sh{
        if [ "$kak_opt_kak_ide_auto_hover" = true ]; then
            echo 'kak-ide-auto-hover-disable'
            echo 'set-option global kak_ide_auto_hover false'
            echo 'echo -markup %{{Information}kak-ide: auto hover OFF}'
        else
            echo 'kak-ide-auto-hover-enable'
            echo 'set-option global kak_ide_auto_hover true'
            echo 'echo -markup %{{Information}kak-ide: auto hover ON}'
        fi
    }
}
