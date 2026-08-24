
define-command -hidden kak-ide-split-guard %{
    evaluate-commands %sh{
        [ -n "${kak_client_env_TMUX:-$TMUX}" ] ||
            printf "fail 'kak-ide splits need tmux: start Kakoune inside a tmux session'\n"
    }
}

# ─── Creating splits ─────────────────────────────────────────────────────────

define-command kak-ide-split-right -docstring %{
    kak-ide-split-right: open a new client of this session in a pane to the right
} %{
    kak-ide-split-guard
    tmux-terminal-horizontal kak -c %val{session} %val{buffile}
}

define-command kak-ide-split-below -docstring %{
    kak-ide-split-below: open a new client of this session in a pane below
} %{
    kak-ide-split-guard
    tmux-terminal-vertical kak -c %val{session} %val{buffile}
}

define-command kak-ide-split-tab -docstring %{
    kak-ide-split-tab: open a new client of this session in a new tmux window
} %{
    kak-ide-split-guard
    tmux-terminal-window kak -c %val{session} %val{buffile}
}

# ─── Opening a specific file in a split ──────────────────────────────────────

define-command -params 1 kak-ide-open-vsplit -docstring %{
    kak-ide-open-vsplit <file>: open <file> in a new pane to the right
} %{
    kak-ide-split-guard
    tmux-terminal-horizontal kak -c %val{session} %arg{1}
}

define-command -params 1 kak-ide-open-hsplit -docstring %{
    kak-ide-open-hsplit <file>: open <file> in a new pane below
} %{
    kak-ide-split-guard
    tmux-terminal-vertical kak -c %val{session} %arg{1}
}

# ─── Moving between splits ───────────────────────────────────────────────────

define-command -hidden -params 1 kak-ide-split-focus %{
    kak-ide-split-guard
    evaluate-commands %sh{
        case "$1" in
            left)  d=-L ;;
            down)  d=-D ;;
            up)    d=-U ;;
            right) d=-R ;;
            *) printf "fail 'kak-ide-split-focus: expected left|down|up|right, got %%s'\n" "$1"; exit 0 ;;
        esac
        TMUX="${kak_client_env_TMUX:-$TMUX}" \
            tmux select-pane "$d" -t "${kak_client_env_TMUX_PANE:-$TMUX_PANE}" >/dev/null 2>&1
    }
}

define-command kak-ide-split-left  -docstring 'focus the pane to the left'  %{ kak-ide-split-focus left  }
define-command kak-ide-split-down  -docstring 'focus the pane below'        %{ kak-ide-split-focus down  }
define-command kak-ide-split-up    -docstring 'focus the pane above'        %{ kak-ide-split-focus up    }
define-command kak-ide-split-focus-right -docstring 'focus the pane to the right' %{ kak-ide-split-focus right }

# ─── Closing ─────────────────────────────────────────────────────────────────

define-command kak-ide-split-close -docstring %{
    kak-ide-split-close: close this pane (refuses if a buffer is modified)
} %{ quit }

define-command kak-ide-split-only -docstring %{
    kak-ide-split-only: close every OTHER pane in this tmux window
} %{
    kak-ide-split-guard
    evaluate-commands %sh{
        TMUX="${kak_client_env_TMUX:-$TMUX}" \
            tmux kill-pane -a -t "${kak_client_env_TMUX_PANE:-$TMUX_PANE}" >/dev/null 2>&1
    }
}

# ─── Keymap ──────────────────────────────────────────────────────────────────

declare-user-mode kak-ide-split

map global user s ': enter-user-mode kak-ide-split<ret>' -docstring 'splits…'

map global kak-ide-split v ': kak-ide-split-right<ret>' -docstring 'split right'
map global kak-ide-split s ': kak-ide-split-below<ret>' -docstring 'split below'
map global kak-ide-split t ': kak-ide-split-tab<ret>'   -docstring 'new tmux window'

map global kak-ide-split h ': kak-ide-split-left<ret>'        -docstring 'focus left'
map global kak-ide-split j ': kak-ide-split-down<ret>'        -docstring 'focus down'
map global kak-ide-split k ': kak-ide-split-up<ret>'          -docstring 'focus up'
map global kak-ide-split l ': kak-ide-split-focus-right<ret>' -docstring 'focus right'

map global kak-ide-split q ': kak-ide-split-close<ret>' -docstring 'close this pane'
map global kak-ide-split o ': kak-ide-split-only<ret>'  -docstring 'close all other panes'
