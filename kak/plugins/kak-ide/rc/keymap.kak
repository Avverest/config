# kak-ide — keybindings
#
# Kakoune's own keys win, everywhere. This file adds only what was otherwise
# unreachable, and only on keys Kakoune leaves free:
#
#   `,` / <space> leader   the `user` mode both keys already open
#   `]` / `[`              unbound in Kakoune; used for bracket-nav
#   goto D / i             goto mode has no D or i of its own
#
# An earlier revision shipped a "Helix parity" module that put pickers on
# <space> and tree-sitter motions on <a-o>/<a-i>/<a-n>/<a-p>. Both are gone:
#
#   <a-i>/<a-a> are Kakoune's object-selection prefixes — the core of the
#   editing model — and <a-o>/<a-n>/<a-p> insert a line, select the previous
#   match, and paste after each selection. Taking those four keys cost more
#   than the motions gained; tree-sitter's own 70 bindings are reached via `,t`.
#
#   <space> needed no relocating in the first place: in Kakoune 2026.05.21 it
#   is already the standard entry to user mode (`:doc keys`, "user mode"), and
#   <a-space> is what drops all but the main selection. The module swapped two
#   keys that were already in the right places.

# ─── Additions to the existing `,` leader ────────────────────────────────────

map global user a  ': lsp-code-actions<ret>'                -docstring 'code actions'
map global user e  ': kaktree-toggle<ret>'                  -docstring 'file explorer'

# Section 8's goto table: kakrc already binds gd/gr/gy. Kakoune leaves `D` and
# `i` free in goto mode (its own goto has no such keys), so the two remaining
# Helix goto targets are added here rather than displacing anything.

map global goto D ': lsp-declaration<ret>'    -docstring 'declaration'
map global goto i ': lsp-implementation<ret>' -docstring 'implementation'

# Buffer navigation (kakoune_bugs.md item 3 asks for Helix's gn/gp).
#
# `gn`/`gp` are NOT reachable. Kakoune's goto mode is implemented in C++ and
# only dispatches keys it already knows: `map global goto n` is accepted and
# even appears in `debug mappings`, but pressing `gn` reports "key not mapped".
# Reproduced in a bare `kak -n` with no config, so this is upstream behaviour,
# not a conflict here. `D`/`i` above work precisely because they ARE goto keys.
#
# So buffer navigation goes on the bracket-nav modes this bundle already owns —
# `]b`/`[b`, alongside `]c`/`]d`/`]f` — plus `<space>n`/`<space>p` on the
# leader. `ga` (Kakoune's own last-buffer) still does the Helix `ga` job.


# ─── Closing buffers (kakoune_bugs.md item 1) ────────────────────────────────
#
# `delete-buffer` refuses a buffer with unsaved changes — "buffer 'x' is
# modified" — and offers nothing further, so the buffer appears unclosable
# unless you already know to type `:delete-buffer!`. This asks instead.

define-command kak-ide-close-buffer -params 0..1 -docstring %{
    kak-ide-close-buffer [buffer]: close a buffer, asking if it has unsaved changes

    Without an argument, closes the current buffer.
} %{
    evaluate-commands %sh{
        # `delete-buffer` with no argument closes the current buffer; passing an
        # empty string is an error, so only forward one when given.
        if [ -n "$1" ]; then printf 'kak-ide-close-buffer-impl %%{%s}\n' "$1"
        else                 printf 'kak-ide-close-buffer-impl %%val{bufname}\n'
        fi
    }
}

# The buffer being closed, held across the prompt. `%arg{1}` is NOT reachable
# from inside the prompt's own %sh block — command arguments are not exported as
# kak_arg_* there, so reading one yields an empty string and the wrong buffer
# (or none) gets deleted. An option survives the callback; a shell variable does
# not.
declare-option -hidden str kak_ide_closing

define-command -hidden -params 1 kak-ide-close-buffer-impl %{
    try %{
        delete-buffer %arg{1}
    } catch %{
        # `delete-buffer` fails only when the buffer has unsaved changes. Left
        # alone it fails silently through fzf, whose window has already closed
        # by the time the error is raised — the buffer simply appears unclosable.
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
#
# kak-tree-sitter installs 70 maps of its own across the `tree-sitter`,
# `tree-sitter-search/-find/-select/-nav-sticky` user modes — parent/child/
# sibling navigation, structural search and find, text-object selection. It also
# already maps object mode: `<a-i>f` function, `<a-i>t` class, `<a-i>a`
# parameter, `<a-i>T` test. (Those override the LSP object maps set earlier in
# kakrc, because kak-tree-sitter initialises after them — which is the better
# outcome: tree-sitter objects are precise where LSP document symbols are
# coarse. kakrc's `<a-i>d` diagnostics object is untouched and still works.)
#
# So nothing here re-implements motions. All that is missing is a way IN to the
# `tree-sitter` mode, plus the Helix-style Alt- shortcuts for the four motions
# used often enough to deserve a top-level key. Argument syntax is copied from
# kak-tree-sitter's own maps: the payload is JSON, and "" is an escaped quote
# inside a Kakoune double-quoted string.

define-command kak-ide-keymap-treesitter-enable -docstring %{
    kak-ide-keymap-treesitter-enable: reach kak-tree-sitter's structural motions

    Adds `,t` to enter tree-sitter mode, where kak-tree-sitter's own 70
    structural bindings live. No normal-mode keys are taken: Kakoune's
    <a-o>/<a-i>/<a-n>/<a-p> keep their native meanings. Object mode is left
    alone — kak-tree-sitter already owns it.
} %{
    map global user t ': enter-user-mode tree-sitter<ret>' -docstring 'tree-sitter mode'

    # kak-tree-sitter maps object mode for function/class/parameter/test but not
    # comment, even though every language it ships queries for here (rust, ts,
    # tsx, js, jsx, lua) defines @comment.inside/@comment.around. Plan §2.3 lists
    # the comment text object as required, so bind it in the same shape upstream
    # uses. `c` is free in object mode — Kakoune's own object mode has no `c`.
    map global object c '<a-;>tree-sitter-object-text-objects comment<ret>' -docstring 'comment (tree-sitter)'
    map global kak-ide-next C ': tree-sitter-text-objects comment.around search_next<ret>' -docstring 'next comment'
    map global kak-ide-prev C ': tree-sitter-text-objects comment.around search_prev<ret>' -docstring 'previous comment'


    echo -markup "{Information}kak-ide: tree-sitter reachable via ,t"
}

# ─── Git: expose what Kakoune's own git.kak already implements ───────────────
#
# `git show-diff` populates the git_diff_flags gutter, `git next-hunk`/`prev-hunk`
# navigate, `git apply --reverse` on a selection resets a hunk. All native, all
# unbound. Section 4 of the plan assumed this needed a third-party plugin.

define-command kak-ide-keymap-git-enable -docstring %{
    kak-ide-keymap-git-enable: bind git hunk navigation and keep the gutter live
} %{
    # Kakoune's `map` binds a single key, so Helix's `]c`/`[c` cannot be mapped
    # directly. Kakoune has no bracket-nav convention of its own and leaves `[`
    # and `]` unbound in normal mode, so Section 8 sanctions adding one: `]`/`[`
    # enter a mode, the second key picks the target. This also gives diagnostics
    # nav (`]d`/`[d`) a home, matching Section 8's table.
    map global normal ']' ': enter-user-mode kak-ide-next<ret>' -docstring 'go to next …'
    map global normal '[' ': enter-user-mode kak-ide-prev<ret>' -docstring 'go to previous …'

    map global kak-ide-next c ': git next-hunk<ret>'        -docstring 'next change (git hunk)'
    map global kak-ide-prev c ': git prev-hunk<ret>'        -docstring 'previous change (git hunk)'
    map global kak-ide-next d ': lsp-find-error<ret>'            -docstring 'next diagnostic'
    map global kak-ide-prev d ': lsp-find-error --previous<ret>' -docstring 'previous diagnostic'
    map global kak-ide-next f ': lsp-next-function<ret>'         -docstring 'next function'
    map global kak-ide-prev f ': lsp-previous-function<ret>'     -docstring 'previous function'
    map global kak-ide-next b ': buffer-next<ret>'               -docstring 'next buffer'
    map global kak-ide-prev b ': buffer-previous<ret>'           -docstring 'previous buffer'

    map global user G ': git show-diff<ret>' -docstring 'refresh git gutter'

    # The gutter is a snapshot: git.kak computes it once and never refreshes.
    # Recompute on open and on write so it tracks reality.
    hook global -group kak-ide-git WinCreate .*    %{ try %{ git show-diff } }
    hook global -group kak-ide-git BufWritePost .* %{ try %{ git show-diff } }
    echo -markup "{Information}kak-ide: git hunk nav bound (]c / [c), gutter auto-refreshes"
}

# ─── Modes used by the git bracket-nav above ─────────────────────────────────

declare-user-mode kak-ide-next
declare-user-mode kak-ide-prev

# fzf.kak's own delete-buffer picker calls plain `delete-buffer`, which fails on
# a modified buffer — and the fzf window has already closed by then, so the
# error is never seen and the buffer just appears not to close. Point it at the
# version that asks. `-override` because fzf.kak defines it in a module that is
# required lazily; this runs after that.
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
