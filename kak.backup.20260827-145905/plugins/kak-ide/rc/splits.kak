
# ─────────────────────────────────────────────────────────────────────────────
# Splits — panes of the host multiplexer, each a client of this same session.
# The backend (wezterm or tmux) is chosen by mux.kak; nothing here knows which.
# ─────────────────────────────────────────────────────────────────────────────

define-command -hidden -params 1 kak-ide-split-client %{
    evaluate-commands %sh{
        # `kak -c` reuses the running server, so the new pane joins this session.
        printf 'kak-ide-mux-split %s 50 %%{kak -c %s %s}\n' \
            "$1" "$kak_session" "${kak_buffile:+\"$kak_buffile\"}"
    }
}

# ─── Creating splits ─────────────────────────────────────────────────────────

define-command kak-ide-split-right -docstring %{
    kak-ide-split-right: open a new client of this session in a pane to the right
} %{ kak-ide-split-client right }

define-command kak-ide-split-below -docstring %{
    kak-ide-split-below: open a new client of this session in a pane below
} %{ kak-ide-split-client below }

define-command kak-ide-split-tab -docstring %{
    kak-ide-split-tab: open a new client of this session in a new window/tab
} %{
    kak-ide-mux-guard
    evaluate-commands %sh{
        printf 'kak-ide-mux-window %%{kak -c %s %s}\n' \
            "$kak_session" "${kak_buffile:+\"$kak_buffile\"}"
    }
}

# ─── Opening a specific file in a split ──────────────────────────────────────

define-command -params 1 kak-ide-open-vsplit -docstring %{
    kak-ide-open-vsplit <file>: open <file> in a new pane to the right
} %{
    kak-ide-mux-guard
    evaluate-commands %sh{
        printf 'kak-ide-mux-split right 50 %%{kak -c %s "%s"}\n' "$kak_session" "$1"
    }
}

define-command -params 1 kak-ide-open-hsplit -docstring %{
    kak-ide-open-hsplit <file>: open <file> in a new pane below
} %{
    kak-ide-mux-guard
    evaluate-commands %sh{
        printf 'kak-ide-mux-split below 50 %%{kak -c %s "%s"}\n' "$kak_session" "$1"
    }
}

# ─── Moving between splits ───────────────────────────────────────────────────

define-command -hidden -params 1 kak-ide-split-focus %{ kak-ide-mux-focus %arg{1} }

define-command kak-ide-split-left  -docstring 'focus the pane to the left'  %{ kak-ide-mux-focus left  }
define-command kak-ide-split-down  -docstring 'focus the pane below'        %{ kak-ide-mux-focus down  }
define-command kak-ide-split-up    -docstring 'focus the pane above'        %{ kak-ide-mux-focus up    }
define-command kak-ide-split-focus-right -docstring 'focus the pane to the right' %{ kak-ide-mux-focus right }

# ─── Sizing ──────────────────────────────────────────────────────────────────

define-command kak-ide-split-zoom -docstring %{
    kak-ide-split-zoom: toggle zoom (fullscreen) for this pane
} %{ kak-ide-mux-zoom-toggle }

# ─── Closing ─────────────────────────────────────────────────────────────────

define-command kak-ide-split-close -docstring %{
    kak-ide-split-close: close this pane (refuses if a buffer is modified)
} %{ quit }

define-command kak-ide-split-only -docstring %{
    kak-ide-split-only: close every OTHER pane in this window
} %{ kak-ide-mux-kill-others }

# ─── Keymap ──────────────────────────────────────────────────────────────────

declare-user-mode kak-ide-split

map global user s ': enter-user-mode kak-ide-split<ret>' -docstring 'splits…'

map global kak-ide-split v ': kak-ide-split-right<ret>' -docstring 'split right'
map global kak-ide-split s ': kak-ide-split-below<ret>' -docstring 'split below'
map global kak-ide-split t ': kak-ide-split-tab<ret>'   -docstring 'new window/tab'

map global kak-ide-split h ': kak-ide-split-left<ret>'        -docstring 'focus left'
map global kak-ide-split j ': kak-ide-split-down<ret>'        -docstring 'focus down'
map global kak-ide-split k ': kak-ide-split-up<ret>'          -docstring 'focus up'
map global kak-ide-split l ': kak-ide-split-focus-right<ret>' -docstring 'focus right'

map global kak-ide-split z ': kak-ide-split-zoom<ret>'  -docstring 'zoom this pane'
map global kak-ide-split q ': kak-ide-split-close<ret>' -docstring 'close this pane'
map global kak-ide-split o ': kak-ide-split-only<ret>'  -docstring 'close all other panes'
