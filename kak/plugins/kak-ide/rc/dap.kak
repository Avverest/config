# kak-ide — debugging (plan Section 2.9, Phase 5)
#
# A DAP client for Kakoune. The protocol work lives in `bin/kak-dap` (a Python
# daemon); this file is the editor half: commands, the breakpoint gutter, the
# stop marker, and the `,`/<space> bindings.
#
# Why a daemon rather than a shell helper like the other kak-ide modules: DAP is
# a long-lived, asynchronous, stateful conversation. The adapter pushes events
# (stopped, output, terminated) whenever it likes, and the client must answer
# reverse-requests. None of that fits a synchronous script that runs and exits.
# The daemon talks back through `kak -p`, the same channel kakoune-lsp uses.
#
# Two adapters, chosen by filetype:
#   rust                        -> lldb-dap   (stdio)
#   javascript/typescript/...   -> js-debug   (TCP + child sessions)

declare-option -docstring "kak-dap: debug session status" str kak_dap_status "off"
declare-option -docstring "kak-dap: breakpoint count" int kak_dap_breakpoint_count 0
declare-option -docstring "kak-dap: control FIFO for the running session" str kak_dap_fifo ""
declare-option -docstring "kak-dap: program being debugged" str kak_dap_program ""
# Breakpoints set before a session exists. Setting breakpoints and *then*
# starting is the normal workflow, but there is no daemon to receive them yet,
# so they are held here (one "path:line" per entry) and replayed at start.
declare-option -docstring "kak-dap: breakpoints set before the session started" str-list kak_dap_pending

# Gutter flags. Breakpoints are per-buffer; the stop marker is a separate line
# flag so clearing it does not disturb the breakpoints.
declare-option -docstring "kak-dap: breakpoint gutter flags" line-specs kak_dap_break_flags
declare-option -docstring "kak-dap: current stop line" line-specs kak_dap_stop_flags

hook global WinCreate .* %{
    add-highlighter window/kak-dap-break flag-lines DapBreakpoint kak_dap_break_flags
    add-highlighter window/kak-dap-stop  flag-lines DapStop       kak_dap_stop_flags
}

set-face global DapBreakpoint red,default
set-face global DapStop       yellow,default

# ─── Session lifecycle ───────────────────────────────────────────────────────

define-command kak-dap-start -params 0..1 -docstring %{
    kak-dap-start [program]: start a debug session

    With no argument the program is guessed from the buffer's filetype and the
    project root: `target/debug/<crate>` for Rust, the buffer itself for JS/TS.
} %{
    evaluate-commands %sh{
        # Kakoune exports only the kak_* variables whose names appear literally
        # in this block (AUDIT.md finding D). `$kak_opt_filetype` is read inside
        # a `case`, which the scanner does see — but `kak_buffile`, `kak_session`
        # and `kak_config` are used only inside branches, so name them here or
        # they arrive empty and the adapter is chosen from an empty filetype.
        : "$kak_opt_filetype" "$kak_buffile" "$kak_session" "$kak_config" \
          "$kak_opt_kak_ide_project_root" "$kak_opt_kak_dap_fifo"
        [ -n "$kak_opt_kak_dap_fifo" ] && {
            printf 'fail %%{kak-dap: a session is already running (kak-dap-stop first)}\n'
            exit
        }
        root="${kak_opt_kak_ide_project_root:-$PWD}"
        prog="$1"

        case "$kak_opt_filetype" in
            rust)       adapter=lldb ;;
            javascript|typescript|jsx|tsx) adapter=node ;;
            "") printf 'fail %%{kak-dap: no filetype — run this from a client editing the file, not from `kak -p`}\n'
                exit ;;
            *)  printf 'fail %%{kak-dap: no adapter for filetype %%{%s} (rust, javascript, typescript, jsx, tsx)}\n' "$kak_opt_filetype"
                exit ;;
        esac

        if [ -z "$prog" ]; then
            if [ "$adapter" = lldb ]; then
                # Cargo names the binary after the package unless [[bin]] says
                # otherwise; prefer an exact match, else the sole executable.
                name=$(sed -n 's/^name[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$root/Cargo.toml" 2>/dev/null | head -1)
                prog="$root/target/debug/$name"
                [ -x "$prog" ] || prog=$(find "$root/target/debug" -maxdepth 1 -type f -perm -111 2>/dev/null | head -1)
            else
                prog="$kak_buffile"
            fi
        fi
        [ -n "$prog" ] && [ -e "$prog" ] || {
            printf 'fail %%{kak-dap: no program to debug (build it first, or pass one: kak-dap-start <path>)}\n'
            exit
        }

        fifo=$(mktemp -u "${TMPDIR:-/tmp}/kak-dap-XXXXXX")
        mkfifo "$fifo" || { printf 'fail %%{kak-dap: cannot create control fifo}\n'; exit; }

        bin="${kak_config}/plugins/kak-ide/bin/kak-dap"
        ( "$bin" "$kak_session" "$fifo" "$adapter" "$root" "$prog" >/dev/null 2>&1 &
        ) >/dev/null 2>&1 </dev/null

        printf 'set-option global kak_dap_fifo %%{%s}\n' "$fifo"
        printf 'set-option global kak_dap_program %%{%s}\n' "$prog"
        # No %{...} around the program name: inside -markup, "{...}" is a FACE,
        # so a name like "app.js" is parsed as a colour and the command fails
        # with "unable to parse color". Only the leading {Information} is markup.
        printf 'echo -markup %%{{Information}kak-dap: starting %s (%s)}\n' "${prog##*/}" "$adapter"
        printf 'kak-dap-replay-pending\n' 
    }
}

define-command kak-dap-stop -docstring "kak-dap-stop: end the debug session" %{
    kak-dap-send %{{"op":"quit"}}
    kak-dap-on-terminated
}

define-command -hidden kak-dap-on-terminated %{
    evaluate-commands %sh{
        [ -n "$kak_opt_kak_dap_fifo" ] && rm -f "$kak_opt_kak_dap_fifo"
        printf 'set-option global kak_dap_fifo %%{}\n'
        printf 'set-option global kak_dap_status %%{off}\n'
    }
    kak-dap-clear-stop-marker
}

# All control flows through one place: a JSON line on the FIFO. Writing to a
# FIFO with no reader blocks forever, so this must never run in the foreground.
define-command -hidden -params 1 kak-dap-send %{
    nop %sh{
        [ -n "$kak_opt_kak_dap_fifo" ] || exit
        ( printf '%s\n' "$1" > "$kak_opt_kak_dap_fifo" & ) >/dev/null 2>&1
    }
}

define-command -hidden kak-dap-replay-pending %{
    evaluate-commands %sh{
        : "$kak_quoted_opt_kak_dap_pending"
        eval set -- "$kak_quoted_opt_kak_dap_pending"
        for bp; do
            printf 'kak-dap-send %%{{"op":"breakpoint","path":"%s","line":%s}}\n' \
                "${bp%:*}" "${bp##*:}"
        done
    }
}

# ─── Breakpoints ─────────────────────────────────────────────────────────────

define-command kak-dap-breakpoint -docstring %{
    kak-dap-breakpoint: toggle a breakpoint on the current line

    Works with no session running: the breakpoint is remembered and applied
    when one starts.
} %{
    evaluate-commands %sh{
        : "$kak_buffile" "$kak_cursor_line" "$kak_opt_kak_dap_fifo"
        if [ -n "$kak_opt_kak_dap_fifo" ]; then
            printf 'kak-dap-send %%{{"op":"breakpoint","path":"%s","line":%s}}\n' \
                "$kak_buffile" "$kak_cursor_line"
        else
            printf 'kak-dap-pending-toggle %%{%s:%s}\n' "$kak_buffile" "$kak_cursor_line"
        fi
    }
}

define-command -hidden -params 1 kak-dap-pending-toggle %{
    evaluate-commands %sh{
        : "$kak_quoted_opt_kak_dap_pending"
        want="$1"
        found=no; out=""
        eval set -- "$kak_quoted_opt_kak_dap_pending"
        for bp; do
            if [ "$bp" = "$want" ]; then found=yes; else
                out="$out $(printf '%s' "$bp" | sed "s/'/''/g; s/^/'/; s/\$/'/")"
            fi
        done
        [ "$found" = no ] && out="$out $(printf '%s' "$want" | sed "s/'/''/g; s/^/'/; s/\$/'/")"
        printf 'set-option global kak_dap_pending%s\n' "$out"
        # Paint the gutter immediately: waiting for a session would leave the
        # user with no feedback that the breakpoint registered at all.
        printf 'kak-dap-pending-repaint\n'
    }
}

define-command -hidden kak-dap-pending-repaint %{
    evaluate-commands %sh{
        : "$kak_quoted_opt_kak_dap_pending" "$kak_buffile"
        eval set -- "$kak_quoted_opt_kak_dap_pending"
        # line-specs is a LIST: "<timestamp>" "<line>|<text>" "<line>|<text>".
        # Joining the specs into one "|"-separated word instead makes Kakoune
        # reject it with "too many elements in tuple" — each spec is its own arg.
        flags=""
        for bp; do
            path="${bp%:*}"; line="${bp##*:}"
            [ "$path" = "$kak_buffile" ] && flags="$flags '$line|●'"
        done
        printf 'set-option buffer kak_dap_break_flags %%val{timestamp}%s\n' "$flags"
    }
}

define-command kak-dap-breakpoint-cond -docstring %{
    kak-dap-breakpoint-cond: set a conditional breakpoint on the current line
} %{
    prompt 'condition: ' %{
        kak-dap-send %sh{
            printf '{"op":"breakpoint","path":"%s","line":%s,"condition":"%s"}' \
                "$kak_buffile" "$kak_cursor_line" "$(printf '%s' "$kak_text" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        }
    }
}

define-command kak-dap-breakpoint-log -docstring %{
    kak-dap-breakpoint-log: set a log point (prints instead of stopping)
} %{
    prompt 'log message: ' %{
        kak-dap-send %sh{
            printf '{"op":"breakpoint","path":"%s","line":%s,"log":"%s"}' \
                "$kak_buffile" "$kak_cursor_line" "$(printf '%s' "$kak_text" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        }
    }
}

# Called by the daemon. `flags` is Kakoune's own line-specs payload.
# <path> <line|text>... — line-specs is a list, so the specs arrive as separate
# arguments rather than one joined string.
define-command -hidden -params 1.. kak-dap-set-breakpoint-flags %{
    evaluate-commands %sh{
        # Only paint a buffer that is actually open: the daemon tracks
        # breakpoints for files that may never have been visited, and
        # `evaluate-commands -buffer` on an unopened file fails the whole call.
        path="$1"; shift
        specs=""
        for sp; do specs="$specs $(printf "%s" "$sp" | sed "s/'/''/g; s/^/'/; s/\$/'/")"; done
        printf 'try %%{ evaluate-commands -buffer %%{%s} %%{ set-option buffer kak_dap_break_flags %%val{timestamp}%s } }\n' \
            "$path" "$specs"
    }
}

define-command -hidden -params 1 kak-dap-set-breakpoint-count %{
    set-option global kak_dap_breakpoint_count %arg{1}
}

# ─── Stop location ───────────────────────────────────────────────────────────

define-command -hidden -params 2 kak-dap-jump-to %{
    # The daemon calls this from `kak -p`, which has no client of its own, and
    # `execute-keys` fails there with "no input handler in context". `-try-client`
    # alone is not enough: it falls back to running client-less when jumpclient
    # is unset. Pick a real client explicitly, and keep the line-selecting keys
    # off the path that can run without one.
    evaluate-commands -client %sh{
        printf '%s' "${kak_opt_jumpclient:-${kak_client:-${kak_client_list%% *}}}"
    } %{
        edit -existing %arg{1} %arg{2}
        execute-keys "%arg{2}g" "x"
        set-option buffer kak_dap_stop_flags %val{timestamp} "%arg{2}|▶"
        try %{ focus }
    }
}

define-command -hidden kak-dap-clear-stop-marker %{
    evaluate-commands -buffer * %{ unset-option buffer kak_dap_stop_flags }
}

# ─── Control ─────────────────────────────────────────────────────────────────

define-command kak-dap-continue  -docstring "kak-dap-continue: resume"            %{ kak-dap-send %{{"op":"continue"}} }
define-command kak-dap-next      -docstring "kak-dap-next: step over"             %{ kak-dap-send %{{"op":"next"}} }
define-command kak-dap-step-in   -docstring "kak-dap-step-in: step into"          %{ kak-dap-send %{{"op":"stepIn"}} }
define-command kak-dap-step-out  -docstring "kak-dap-step-out: step out"          %{ kak-dap-send %{{"op":"stepOut"}} }
define-command kak-dap-pause     -docstring "kak-dap-pause: interrupt"            %{ kak-dap-send %{{"op":"pause"}} }
define-command kak-dap-variables -docstring "kak-dap-variables: locals in frame"  %{ kak-dap-send %{{"op":"variables"}} }
define-command kak-dap-stack     -docstring "kak-dap-stack: call stack"           %{ kak-dap-send %{{"op":"stack"}} }

define-command kak-dap-frame -params 1 -docstring %{
    kak-dap-frame <n>: select stack frame n and jump to it
} %{
    kak-dap-send %sh{ printf '{"op":"frame","n":%s}' "$1" }
}

define-command kak-dap-status -docstring "kak-dap-status: what the debugger is doing" %{
    info -title "kak-dap" "status:      %opt{kak_dap_status}
program:     %opt{kak_dap_program}
breakpoints: %opt{kak_dap_breakpoint_count}"
}

# ─── Keymap ──────────────────────────────────────────────────────────────────

declare-user-mode kak-dap

map global kak-dap b ': kak-dap-breakpoint<ret>'       -docstring 'toggle breakpoint'
map global kak-dap B ': kak-dap-breakpoint-cond<ret>'  -docstring 'conditional breakpoint'
map global kak-dap l ': kak-dap-breakpoint-log<ret>'   -docstring 'log point'
map global kak-dap s ': kak-dap-start<ret>'            -docstring 'start debugging'
map global kak-dap q ': kak-dap-stop<ret>'             -docstring 'stop debugging'
map global kak-dap c ': kak-dap-continue<ret>'         -docstring 'continue'
map global kak-dap n ': kak-dap-next<ret>'             -docstring 'step over'
map global kak-dap i ': kak-dap-step-in<ret>'          -docstring 'step into'
map global kak-dap o ': kak-dap-step-out<ret>'         -docstring 'step out'
map global kak-dap p ': kak-dap-pause<ret>'            -docstring 'pause'
map global kak-dap v ': kak-dap-variables<ret>'        -docstring 'variables'
map global kak-dap k ': kak-dap-stack<ret>'            -docstring 'call stack'
map global kak-dap '?' ': kak-dap-status<ret>'         -docstring 'session status'

define-command kak-ide-keymap-dap-enable -docstring %{
    kak-ide-keymap-dap-enable: bind the debugger under the leader

    Adds `d` to both leaders (`,d` and <space>d) as the debug mode. Note that
    kakrc binds `,d` to :delete-buffer; this only claims it in the kak-ide mode
    unless that binding is free.
} %{
    map global kak-ide d ': enter-user-mode kak-dap<ret>' -docstring 'debug (DAP)'
    echo -markup "{Information}kak-dap: debug mode on <space>d"
}
