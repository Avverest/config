# kak-ide — keybindings  (plan Section 8)
#
# Section 8's target table puts every picker on `<space>`. Section 8 rule 4 says
# that where a Helix key collides with a long-standing Kakoune key, Kakoune wins
# and the Helix action goes on a secondary binding — "Kakoune, IDE-ified", not
# "Helix wearing a Kakoune costume". `<space>` is exactly that case: in Kakoune
# it drops all but the main selection, which is core, muscle-memory editing.
# This config already reached the same conclusion and uses `,` as its leader.
#
# So, per rule 4 and rule 5 ("ship the full set as one togglable keymap module"):
#
#   default    — new actions are added to the existing `,` leader, using only
#                letters that were free. Nothing already bound is reassigned.
#   opt-in     — `:kak-ide-keymap-helix-enable` installs the full Section 8
#                table on `<space>`, relocating Kakoune's `<space>` to `<a-space>`.
#
# Conflicts left deliberately unresolved in the default map, because the
# existing binding is the user's and predates this work:
#   ,r  recent files      (Section 8 wants: rename symbol -> placed on ,R)
#   ,d  delete buffer     (Section 8 wants: diagnostics   -> placed on ,D)
#   ,?  cheat sheet       (Section 8 wants: palette       -> placed on ,:)
#
# Note on ,x: an earlier revision placed diagnostics there, but `kakrc` binds
# ,x to :write-quit and is sourced AFTER this module, so kakrc silently won and
# the diagnostics picker was unreachable. Verified with `debug mappings`.
# It now lives on ,D, which was free and matches Helix's `Space D` anyway.

# ─── Additions to the existing `,` leader ────────────────────────────────────

map global user a  ': lsp-code-actions<ret>'                -docstring 'code actions'
map global user R  ': kak-ide-rename<ret>'                  -docstring 'rename symbol (workspace, reviewable)'
map global user g  ': kak-ide-picker-changed<ret>'          -docstring 'changed files (git)'
map global user j  ': kak-ide-picker-jumps<ret>'            -docstring 'recent locations'
map global user "'" ': kak-ide-picker-last<ret>'            -docstring 'last picker'
map global user e  ': kaktree-toggle<ret>'                  -docstring 'file explorer'
map global user D  ': kak-ide-picker-diagnostics<ret>'      -docstring 'diagnostics (workspace)'
map global user ':' ': kak-ide-picker-palette<ret>'         -docstring 'command palette'
map global user '%' ': kak-ide-replace<ret>'                -docstring 'project-wide find & replace'

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

# `gf` — Kakoune's native goto-file only opens a literal selected path. This
# replaces it with import-aware resolution and keeps the native behaviour as the
# last fallback, so it is strictly a superset (§8 rule 4 conflict does not apply).
map global goto f ': kak-ide-goto-file<ret>'                -docstring 'file / import under cursor'

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

    Adds `,t` to enter tree-sitter mode (where its own 70 bindings live) and
    Helix-style <a-o>/<a-i>/<a-n>/<a-p> for parent/child/sibling. Object mode is
    left alone — kak-tree-sitter already owns it.
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

    map global normal <a-o> ":tree-sitter-nav '""parent""'<ret>"                                  -docstring 'expand to parent node'
    map global normal <a-i> ":tree-sitter-nav '""first_child""'<ret>"                             -docstring 'shrink to first child'
    map global normal <a-n> ":tree-sitter-nav '{ ""next_sibling"": { ""cousin"": false } }'<ret>" -docstring 'next sibling node'
    map global normal <a-p> ":tree-sitter-nav '{ ""prev_sibling"": { ""cousin"": false } }'<ret>" -docstring 'previous sibling node'

    echo -markup "{Information}kak-ide: tree-sitter reachable via ,t and <a-o>/<a-i>/<a-n>/<a-p>"
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

# ─── Full Helix-parity map (opt-in, Section 8 rule 5) ────────────────────────

declare-user-mode kak-ide
declare-user-mode kak-ide-next
declare-user-mode kak-ide-prev

map global kak-ide f  ': kak-ide-picker-files<ret>'             -docstring 'find file (project)'
map global kak-ide F  ': kak-ide-picker-files-cwd<ret>'         -docstring 'find file (buffer dir)'
map global kak-ide b  ': kak-ide-picker-buffers<ret>'           -docstring 'buffers'
map global kak-ide g  ': kak-ide-picker-changed<ret>'           -docstring 'changed files (git)'
map global kak-ide j  ': kak-ide-picker-jumps<ret>'             -docstring 'recent locations'
map global kak-ide s  ': kak-ide-picker-symbols<ret>'           -docstring 'symbols (document)'
map global kak-ide S  ': kak-ide-picker-symbols-workspace<ret>' -docstring 'symbols (workspace)'
map global kak-ide d  ': kak-ide-picker-diagnostics<ret>'       -docstring 'diagnostics'
map global kak-ide D  ': kak-ide-picker-diagnostics<ret>'       -docstring 'diagnostics (workspace — same picker; kakoune-lsp has no document-scoped variant)'
map global kak-ide '/' ': kak-ide-picker-grep<ret>'             -docstring 'global search'
map global kak-ide '?' ': kak-ide-picker-palette<ret>'          -docstring 'command palette'
map global kak-ide "'" ': kak-ide-picker-last<ret>'             -docstring 'last picker'
map global kak-ide e  ': kaktree-toggle<ret>'                   -docstring 'file explorer'
map global kak-ide '.' ': kaktree-focus<ret>'                   -docstring 'focus file explorer'
map global kak-ide r  ': kak-ide-rename<ret>'                   -docstring 'rename symbol (reviewable)'
map global kak-ide a  ': lsp-code-actions<ret>'                 -docstring 'code actions'
map global kak-ide k  ': lsp-hover<ret>'                        -docstring 'hover docs'
map global kak-ide '%' ': kak-ide-replace<ret>'                 -docstring 'project-wide find & replace'
map global kak-ide v  ': kak-ide-picker-files-vsplit<ret>'      -docstring 'find file -> open right'
map global kak-ide h  ': kak-ide-picker-files-hsplit<ret>'      -docstring 'find file -> open below'

# With `<space>` as the leader, this mode — not `user` — is what the leader
# actually opens, so anything that lived only on `,` becomes unreachable. These
# carry over the everyday commands from kakrc's `user` mode. They are the same
# actions on the same letters, so muscle memory is unaffected either way.
#
# `n`/`p` for buffer navigation also answer kakoune_bugs.md item 3 (Helix's
# gn/gp); `d` there is Kakoune's delete-buffer, answering item 1.

map global kak-ide w ': write<ret>'            -docstring 'write (save)'
map global kak-ide W ': write-all<ret>'        -docstring 'write all buffers'
map global kak-ide q ': quit<ret>'             -docstring 'quit'
map global kak-ide c ': comment-line<ret>'     -docstring 'toggle line comment'
map global kak-ide '=' ': format<ret>'         -docstring 'format buffer'
map global kak-ide n ': buffer-next<ret>'      -docstring 'next buffer'
map global kak-ide p ': buffer-previous<ret>'  -docstring 'previous buffer'
map global kak-ide B ': kak-ide-close-buffer<ret>' -docstring 'close buffer (asks if modified)'

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
map global kak-ide l ': enter-user-mode lsp<ret>'         -docstring 'LSP mode'
map global kak-ide t ': enter-user-mode tree-sitter<ret>' -docstring 'tree-sitter mode'
map global kak-ide z ': fzf-mode<ret>'         -docstring 'fzf menu (all pickers)'
map global kak-ide '?' ': kak-ide-picker-palette<ret>'    -docstring 'command palette'

define-command kak-ide-keymap-helix-enable -docstring %{
    kak-ide-keymap-helix-enable: put the Section 8 picker table on <space>

    Relocates Kakoune's own <space> (drop all but the main selection) to
    <a-space>, which is otherwise unbound. Reverse with
    kak-ide-keymap-helix-disable.
} %{
    map global normal <space>   ': enter-user-mode kak-ide<ret>' -docstring 'kak-ide leader'
    map global normal <a-space> '<space>'                        -docstring 'drop all but main selection'
    echo -markup "{Information}kak-ide: <space> is the leader; Kakoune's <space> moved to <a-space>"
}

define-command kak-ide-keymap-helix-disable -docstring %{
    kak-ide-keymap-helix-disable: give <space> back to Kakoune
} %{
    unmap global normal <space>
    unmap global normal <a-space>
    echo -markup "{Information}kak-ide: <space> restored to Kakoune"
}
