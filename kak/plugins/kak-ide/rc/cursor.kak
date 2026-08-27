declare-option -docstring %{
    kak-ide: DECSCUSR shape used in insert mode (5 blinking bar, 6 steady bar)
} str kak_ide_cursor_insert "6"

declare-option -docstring %{
    kak-ide: DECSCUSR shape restored outside insert mode (1 blinking block, 2 steady block)
} str kak_ide_cursor_normal "2"

define-command kak-ide-cursor-enable -docstring %{
    kak-ide-cursor-enable: use a bar cursor in insert mode, a block elsewhere
} %{
    hook global ModeChange '(push|pop):.*:insert' -group kak-ide-cursor %{
        kak-ide-cursor-set %opt{kak_ide_cursor_insert}
    }

    hook global ModeChange '(push|pop):insert:.*' -group kak-ide-cursor %{
        kak-ide-cursor-set %opt{kak_ide_cursor_normal}
    }

    hook global KakEnd .* -group kak-ide-cursor %{
        kak-ide-cursor-set %opt{kak_ide_cursor_normal}
    }
}

define-command kak-ide-cursor-disable -docstring %{
    kak-ide-cursor-disable: stop switching the terminal cursor shape
} %{
    remove-hooks global kak-ide-cursor
    kak-ide-cursor-set %opt{kak_ide_cursor_normal}
}

define-command -hidden -params 1 kak-ide-cursor-set %{
    nop %sh{
        tty=$(ps -o tty= -p "$kak_client_pid" 2>/dev/null | tr -d ' ')
        case "$tty" in
            ''|'??'|'?') exit 0 ;;
        esac

        if [ -n "${kak_client_env_TMUX:-}" ]; then
            printf '\033Ptmux;\033\033[%s q\033\\' "$1" > "/dev/$tty" 2>/dev/null
        else
            printf '\033[%s q' "$1" > "/dev/$tty" 2>/dev/null
        fi
    }
}
