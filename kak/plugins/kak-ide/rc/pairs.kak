define-command kak-ide-pairs-enable -docstring %{
    kak-ide-pairs-enable: auto-insert closing brackets and quotes
} %{
    hook global InsertChar '\(' -group kak-ide-pairs %{ execute-keys -draft ')' }
    hook global InsertChar '\[' -group kak-ide-pairs %{ execute-keys -draft ']' }
    hook global InsertChar '\{' -group kak-ide-pairs %§ execute-keys -draft '}' §

    hook global InsertChar "'" -group kak-ide-pairs %{
        try %{
            execute-keys -draft "hh<a-k>[\w'\\]<ret>"
        } catch %{
            execute-keys -draft "'"
        }
    }

    hook global InsertChar '"' -group kak-ide-pairs %{
        try %{
            execute-keys -draft 'hh<a-k>[\w"\\]<ret>'
        } catch %{
            execute-keys -draft '"'
        }
    }

    hook global InsertChar '`' -group kak-ide-pairs %{
        try %{
            execute-keys -draft 'hh<a-k>[\w`\\]<ret>'
        } catch %{
            execute-keys -draft '`'
        }
    }
}

define-command kak-ide-pairs-disable -docstring %{
    kak-ide-pairs-disable: stop auto-inserting closing characters
} %{
    remove-hooks global kak-ide-pairs
}
