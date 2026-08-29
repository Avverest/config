define-command -override \
    -params 2 \
    -docstring "
        inc-dec-modify-numbers OP NUM

        Apply the given operator (usually + or -) and NUM to each selected
        number. For example, 'inc-dec-modify-numbers + 3' adds 3 to all selected
        numbers. If NUM is 0, it is replaced with 1 since adding or subtracting
        0 is not useful.
        " \
    inc-dec \
%{
    evaluate-commands -save-regs 'c' %{
        # "c" stores the count we want to use (in decimal)
        set-register c %sh{ echo $(( $2 == 0 ? 1 : $2 )) }

        try %{
            # Search for tokens that look like hex numbers.
            execute-keys s \b0[Xx][0-9A-Fa-f]+\b <ret>
            # Apply our operator with shell arithmetic.
            execute-keys | "read val; printf '0x%%0*X\n' $((${#val} - 2)) $(($val %arg{1} %reg{c}))" <ret>

        } catch %{
            # Search for tokens that look like like new-style octal numbers.
            execute-keys s \b0[Oo][0-7]+\b <ret>
            # Convert them to old-style octal numbers, because that's all the
            # shell understands.
            execute-keys | "tr -d Oo" <ret>
            # Apply our operator with shell arithmetic.
            execute-keys | "read val; printf '0o%%0*o\n' $((${#val} - 1)) $(($val %arg{1} %reg{c}))" <ret>

        } catch %{
            # Search for tokens that look like zero-padded decimal numbers.
            execute-keys s [+-]?\b0[0-9]*\b <ret>
            # Apply our operator with shell arithmetic.
            execute-keys | "read val; printf '%%0*d\n' ${#val} $(($(echo ""$val"" | sed -E 's/^([-+])?0+/\1/') %arg{1} %reg{c}))" <ret>

        } catch %{
            # Search for tokens that look like unpadded decimal numbers.
            execute-keys s [+-]?\b[1-9][0-9]*\b <ret>
            # Apply our operator with shell arithmetic.
            execute-keys | "read val; printf '%%d\n' $(($val %arg{1} %reg{c}))" <ret>
        }
    }
}


# `inc-dec` takes an operator and a count, which is awkward to reach for. These
# wrap it in the vim-conventional pair, taking the count from the register that
# `execute-keys` leaves it in, so `3<c-a>` adds three.

define-command -override kak-ide-number-increment -params ..1 \
    -docstring "kak-ide-number-increment [n]: add n (default 1) to selected numbers" %{
    inc-dec + %sh{ echo "${1:-1}" }
}

define-command -override kak-ide-number-decrement -params ..1 \
    -docstring "kak-ide-number-decrement [n]: subtract n (default 1) from selected numbers" %{
    inc-dec - %sh{ echo "${1:-1}" }
}

define-command -override kak-ide-keymap-numbers-enable \
    -docstring "bind <c-a>/<c-x> to increment/decrement the selected numbers" %{
    map global normal <c-a> ': kak-ide-number-increment<ret>' -docstring 'increment number'
    map global normal <c-x> ': kak-ide-number-decrement<ret>' -docstring 'decrement number'
}
