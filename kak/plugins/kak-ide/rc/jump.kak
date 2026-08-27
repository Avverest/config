
# ─── Two-character label jump (`gw`) ─────────────────────────────────────────
#
# Labels every word start in the visible window with a two-character tag, then
# jumps to whichever tag you type. Labels are drawn with a `replace-ranges`
# highlighter, so nothing is ever written to the buffer — an abort restores the
# view untouched.

declare-option -docstring %{
    kak_ide_jump_keys: characters used to build two-character jump labels,
    in the order they are assigned
} str kak_ide_jump_keys "asdfghjklqwertyuiopnmzxcvb"

declare-option -docstring %{
    kak_ide_jump_regex: what counts as a jump target in the visible window
} str kak_ide_jump_regex "\b\w"

declare-option -hidden range-specs kak_ide_jump_labels
declare-option -hidden str kak_ide_jump_targets
declare-option -hidden str kak_ide_jump_prefix

set-face global KakIdeJumpLabel     "black,rgb:ffcc00+b"
set-face global KakIdeJumpLabelTail "black,rgb:00cc66+b"

define-command kak-ide-jump -docstring %{
    kak-ide-jump: label every word start in the window, jump to the one you type
} %{
    kak-ide-jump-collect
    evaluate-commands %sh{
        [ -z "$kak_opt_kak_ide_jump_targets" ] \
            && printf 'fail %%{kak-ide-jump: nothing to label in view}\n'
    }
    set-option window kak_ide_jump_prefix ""
    add-highlighter -override window/kak-ide-jump replace-ranges kak_ide_jump_labels
    kak-ide-jump-render
    kak-ide-jump-await
}

# Walk the visible lines, record every match of kak_ide_jump_regex as a
# "line.column" token in kak_ide_jump_targets. Runs -draft so the user's real
# selection is never disturbed.
define-command -hidden kak-ide-jump-collect %{
    set-option window kak_ide_jump_targets ""
    evaluate-commands -draft -save-regs '/' %{
        evaluate-commands %sh{
            set -- $kak_window_range
            first=$(( ${1:-0} + 1 ))
            height=${3:-0}
            [ "$height" -lt 1 ] && height=1
            last=$(( first + height - 1 ))
            [ "$last" -gt "$kak_buf_line_count" ] && last=$kak_buf_line_count
            printf 'select %d.1,%d.1\n' "$first" "$last"
            printf 'execute-keys <a-L>\n'
        }
        set-register / %opt{kak_ide_jump_regex}
        try %{
            execute-keys 's<ret>'
            evaluate-commands -itersel %{
                set-option -add window kak_ide_jump_targets "%val{cursor_line}.%val{cursor_column} "
            }
        }
    }
}

# Assign labels and build the range-specs the highlighter draws. With a prefix
# already typed, only the matching labels stay lit and just their second
# character is shown.
define-command -hidden kak-ide-jump-render %{
    evaluate-commands %sh{
        keys=$kak_opt_kak_ide_jump_keys
        prefix=$kak_opt_kak_ide_jump_prefix
        nkeys=${#keys}

        set -- $kak_opt_kak_ide_jump_targets
        specs=""
        i=0
        for t in "$@"; do
            line=${t%%.*}
            col=${t#*.}
            a=$(( i / nkeys ))
            b=$(( i % nkeys ))
            i=$(( i + 1 ))
            [ "$a" -ge "$nkeys" ] && break
            rest=$keys; n=$a
            while [ "$n" -gt 0 ]; do rest=${rest#?}; n=$(( n - 1 )); done
            c1=${rest%"${rest#?}"}
            rest=$keys; n=$b
            while [ "$n" -gt 0 ]; do rest=${rest#?}; n=$(( n - 1 )); done
            c2=${rest%"${rest#?}"}

            if [ -n "$prefix" ]; then
                [ "$c1" != "$prefix" ] && continue
                specs="$specs '$line.$col,$line.$col|{KakIdeJumpLabelTail}$c2'"
            else
                end=$(( col + 1 ))
                specs="$specs '$line.$col,$line.$end|{KakIdeJumpLabel}$c1$c2'"
            fi
        done
        printf 'set-option window kak_ide_jump_labels %%val{timestamp}%s\n' "$specs"
    }
}

define-command -hidden kak-ide-jump-await %{
    on-key %{
        evaluate-commands %sh{
            case "$kak_key" in
                '<esc>'|'<c-c>') printf 'kak-ide-jump-abort\n' ;;
                *)               printf 'kak-ide-jump-key %%val{key}\n' ;;
            esac
        }
    }
}

define-command -hidden -params 1 kak-ide-jump-key %{
    evaluate-commands %sh{
        key=$1
        keys=$kak_opt_kak_ide_jump_keys
        # Only single printable characters from the label alphabet can be part
        # of a label; anything else cancels.
        case "$key" in
            [a-zA-Z]) ;;
            *) printf 'kak-ide-jump-abort\n'; exit ;;
        esac
        case "$keys" in
            *"$key"*) ;;
            *) printf 'kak-ide-jump-abort\n'; exit ;;
        esac

        if [ -z "$kak_opt_kak_ide_jump_prefix" ]; then
            printf 'set-option window kak_ide_jump_prefix %s\n' "$key"
            printf 'kak-ide-jump-render\n'
            printf 'kak-ide-jump-await\n'
        else
            printf 'kak-ide-jump-goto %s %s\n' "$kak_opt_kak_ide_jump_prefix" "$key"
        fi
    }
}

define-command -hidden -params 2 kak-ide-jump-goto %{
    evaluate-commands %sh{
        keys=$kak_opt_kak_ide_jump_keys
        nkeys=${#keys}

        a=-1; b=-1; i=0; rest=$keys
        while [ -n "$rest" ]; do
            ch=${rest%"${rest#?}"}
            [ "$ch" = "$1" ] && [ "$a" -lt 0 ] && a=$i
            [ "$ch" = "$2" ] && [ "$b" -lt 0 ] && b=$i
            rest=${rest#?}
            i=$(( i + 1 ))
        done
        if [ "$a" -lt 0 ] || [ "$b" -lt 0 ]; then
            printf 'kak-ide-jump-abort\n'
            exit
        fi
        idx=$(( a * nkeys + b ))

        set -- $kak_opt_kak_ide_jump_targets
        eval "target=\${$(( idx + 1 ))}"
        if [ -z "$target" ]; then
            printf 'kak-ide-jump-abort\n'
            exit
        fi
        line=${target%%.*}
        col=${target#*.}
        printf 'kak-ide-jump-clear\n'
        printf 'select %s.%s,%s.%s\n' "$line" "$col" "$line" "$col"
    }
}

define-command -hidden kak-ide-jump-abort %{
    kak-ide-jump-clear
    echo -markup "{Information}jump cancelled"
}

define-command -hidden kak-ide-jump-clear %{
    try %{ remove-highlighter window/kak-ide-jump }
    set-option window kak_ide_jump_labels %val{timestamp}
    set-option window kak_ide_jump_prefix ""
    set-option window kak_ide_jump_targets ""
}

map global goto w '<esc>: kak-ide-jump<ret>' -docstring 'jump to a two-character label'
