
# ─── Additions to the existing `,` leader ────────────────────────────────────

map global user a  ': lsp-code-actions<ret>'                -docstring 'code actions'
map global user e  ': kaktree-toggle<ret>'                  -docstring 'file explorer'
map global user E  ': kak-ide-files<ret>'                   -docstring 'file manager (yazi)'

# ─── Closing buffers (kakoune_bugs.md item 1) ────────────────────────────────

define-command kak-ide-close-buffer -params 0..1 -docstring %{
    kak-ide-close-buffer [buffer]: close a buffer, asking if it has unsaved changes

    Without an argument, closes the current buffer.
} %{
    evaluate-commands %sh{
        if [ -n "$1" ]; then printf 'kak-ide-close-buffer-impl %%{%s}\n' "$1"
        else                 printf 'kak-ide-close-buffer-impl %%val{bufname}\n'
        fi
    }
}

declare-option -hidden str kak_ide_closing

define-command -hidden -params 1 kak-ide-close-buffer-impl %{
    try %{
        delete-buffer %arg{1}
    } catch %{
        set-option global kak_ide_closing %arg{1}
        prompt -on-abort %{ echo -markup "{Information}kept" } \
               "%arg{1} modified — (w)rite and close, (d)iscard, (c)ancel: " %{
            evaluate-commands %sh{
                : "$kak_opt_kak_ide_closing" "$kak_text"
                b="$kak_opt_kak_ide_closing"
                case "$kak_text" in
                    w*) printf 'evaluate-commands -buffer %%{%s} %%{ write }\ndelete-buffer %%{%s}\necho -markup %%{{Information}written and closed}\n' "$b" "$b" ;;
                    d*) printf 'delete-buffer! %%{%s}\necho -markup %%{{Information}discarded}\n' "$b" ;;
                    *)  printf 'echo -markup %%{{Information}kept}\n' ;;
                esac
            }
        }
    }
}

# ─── Structural editing: reach what kak-tree-sitter already installs ────────

define-command kak-ide-keymap-treesitter-enable -docstring %{
    kak-ide-keymap-treesitter-enable: reach kak-tree-sitter's structural motions

    Adds `,t` to enter tree-sitter mode, where kak-tree-sitter's own 70
    structural bindings live. No normal-mode keys are taken: Kakoune's
    <a-o>/<a-i>/<a-n>/<a-p> keep their native meanings. Object mode is left
    alone — kak-tree-sitter already owns it.
} %{
    map global user t ': enter-user-mode tree-sitter<ret>' -docstring 'tree-sitter mode'

    map global object c '<a-;>tree-sitter-object-text-objects comment<ret>' -docstring 'comment (tree-sitter)'
    map global kak-ide-next C ': tree-sitter-text-objects comment.around search_next<ret>' -docstring 'next comment'
    map global kak-ide-prev C ': tree-sitter-text-objects comment.around search_prev<ret>' -docstring 'previous comment'

    echo -markup "{Information}kak-ide: tree-sitter reachable via ,t"
}

# ─── Git: expose what Kakoune's own git.kak already implements ───────────────

define-command kak-ide-keymap-git-enable -docstring %{
    kak-ide-keymap-git-enable: bind git hunk navigation and keep the gutter live
} %{
    map global user ')' ': enter-user-mode kak-ide-next<ret>' -docstring 'go to next (hunk/diagnostic/…)'
    map global user '(' ': enter-user-mode kak-ide-prev<ret>' -docstring 'go to previous (hunk/diagnostic/…)'

    map global kak-ide-next c ': git next-hunk<ret>'        -docstring 'next change (git hunk)'
    map global kak-ide-prev c ': git prev-hunk<ret>'        -docstring 'previous change (git hunk)'
    map global kak-ide-next d ': lsp-find-error<ret>'            -docstring 'next diagnostic'
    map global kak-ide-prev d ': lsp-find-error --previous<ret>' -docstring 'previous diagnostic'
    map global kak-ide-next f ': lsp-next-function<ret>'         -docstring 'next function'
    map global kak-ide-prev f ': lsp-previous-function<ret>'     -docstring 'previous function'
    map global kak-ide-next b ': buffer-next<ret>'               -docstring 'next buffer'
    map global kak-ide-prev b ': buffer-previous<ret>'           -docstring 'previous buffer'

    map global user G ': git show-diff<ret>' -docstring 'refresh git gutter'

    hook global -group kak-ide-git WinCreate .*    %{ try %{ git show-diff } }
    hook global -group kak-ide-git BufWritePost .* %{ try %{ git show-diff } }
    echo -markup "{Information}kak-ide: git hunk nav bound (]c / [c), gutter auto-refreshes"
}

# ─── Modes used by the git bracket-nav above ─────────────────────────────────

declare-user-mode kak-ide-next
declare-user-mode kak-ide-prev

hook global ModuleLoaded fzf-buffer %{
    define-command -override -hidden fzf-delete-buffer %{ evaluate-commands %sh{
        buffers=""
        eval "set -- ${kak_quoted_buflist:?}"
        while [ $# -gt 0 ]; do
            buffers="$1
$buffers"
            shift
        done
        printf "%s\n" "info -title 'fzf delete-buffer' 'Delete buffer.
<ret>: delete selected buffer (asks if modified).'"
        printf "%s\n" "fzf -kak-cmd %{kak-ide-close-buffer} -multiple-cmd %{kak-ide-close-buffer} -items-cmd %{printf \"%s\n\" \"$buffers\"} -fzf-args %{-m --expect ${kak_opt_fzf_window_map:-ctrl-w} ${additional_flags:-}}"
    }}
}
