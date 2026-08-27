declare-user-mode kak-ide-surround

define-command kak-ide-keymap-surround-enable -docstring %{
    kak-ide-keymap-surround-enable: bind surround verbs under ,m
} %{
    map global user m ': enter-user-mode kak-ide-surround<ret>' -docstring 'surround…'

    map global kak-ide-surround a ': surround<ret>'        -docstring 'add (then any char)'
    map global kak-ide-surround d ': delete-surround<ret>' -docstring 'delete (then any char)'
    map global kak-ide-surround r ': change-surround<ret>' -docstring 'replace (then old, new)'
    map global kak-ide-surround s ': select-surround<ret>' -docstring 'select surrounding pair'

    map global kak-ide-surround t ': surround-with-tag<ret>'       -docstring 'wrap in HTML tag'
    map global kak-ide-surround T ': delete-surrounding-tag<ret>'  -docstring 'remove HTML tags'
    map global kak-ide-surround C ': change-surrounding-tag<ret>'  -docstring 'change HTML tag'
    map global kak-ide-surround S ': select-surrounding-tag<ret>'  -docstring 'select HTML tag'
}
