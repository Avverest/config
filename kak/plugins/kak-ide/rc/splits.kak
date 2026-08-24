# kak-ide — window splits over tmux
#
# Kakoune has no internal splits. A "split" is a second CLIENT of the same
# session in an adjacent terminal pane: both clients share the buffer list and
# every edit, so this is closer to Vim's `:split` than the name suggests.
#
# Kakoune already ships the pane-creating half of this in
# rc/windowing/tmux.kak — `tmux-terminal-vertical` / `-horizontal` / `-window`,
# loaded automatically when $TMUX is set. What it has no command for is moving
# FOCUS between panes, which is what makes splits usable. That is what this
# module adds, plus thin wrappers so creating and closing a split are named
# consistently alongside it.
#
# Everything shells out with the CLIENT's tmux environment, falling back to the
# server's, exactly as Kakoune's own tmux.kak does (see tmux-terminal-impl:13):
#
#     tmux=${kak_client_env_TMUX:-$TMUX}
#
# The distinction matters with more than one pane: the server inherits $TMUX
# from whichever client started it, so using it alone would target that pane no
# matter which client ran the command. $kak_client_env_TMUX is set for any
# interactive client; the fallback covers control clients (`kak -p`), which have
# no pane of their own.

# Shared guard: fail with a visible message when this client is not in tmux.
#
# Same env rule as the header: client first, server as fallback.
define-command -hidden kak-ide-split-guard %{
    evaluate-commands %sh{
        [ -n "${kak_client_env_TMUX:-$TMUX}" ] ||
            printf "fail 'kak-ide splits need tmux: start Kakoune inside a tmux session'\n"
    }
}

# ─── Creating splits ─────────────────────────────────────────────────────────
#
# A new client of THIS session, so buffers are shared. `-c %val{session}`
# attaches rather than starting a second server.
#
# Naming follows the editor's point of view, not tmux's: "right" and "below"
# say where the new pane lands. tmux calls those `split-window -h` and `-v`
# (it names the split by the orientation of the divider), which is the opposite
# intuition, hence `tmux-terminal-horizontal` for a pane on the right.

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
#
# Same as above but for a named file, so a picker can hand a result to a new
# pane. The path is passed through to the new client's argv.

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
#
# The piece Kakoune ships no equivalent for. `select-pane -L/-D/-U/-R` is
# tmux's directional focus; `nop` because there is nothing to feed back into
# Kakoune — the pane switch happens entirely in the terminal.

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
#
# Closing is just quitting this client; tmux reaps the pane when its process
# exits. `quit` (not `quit!`) so a modified buffer still stops you — the last
# client quitting would otherwise lose the edit.

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
#
# `,s` opens a submode rather than taking six top-level leader keys, and gives
# autoinfo something to show. `s` was free on the leader once the symbol picker
# moved out.
#
# hjkl for focus matches the motion keys; v/s for the two splits follows the
# vsplit/split naming most editors use.

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
