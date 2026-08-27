# ─────────────────────────────────────────────────────────────────────────────
# Terminal-multiplexer glue.
#
# Kakoune's own `rc/windowing/` provides backend detection and the
# `terminal` / `new` / `focus` abstraction, with wezterm and tmux modules that
# already read the pane id from the CLIENT's environment. That is the whole
# contract splits.kak needs, so it is used directly rather than reimplemented.
#
# What remains here is only what the builtin modules do not express:
#
#   * a sized panel      — `terminal` takes no width/height percentage
#   * directional focus  — builtin `focus` targets a Kakoune client, not the
#                          pane in a given direction
#   * zoom, kill-others  — no builtin equivalent
#
# Those still need the raw backend, so the per-client detection below is kept
# for them alone. It reads `kak_client_env_*`, never the server's own
# environment: one session can have clients in several panes, and the server
# env only reflects whichever one happened to start it.
# ─────────────────────────────────────────────────────────────────────────────

declare-option -docstring %{
    Which multiplexer backend the current client can drive: wezterm, tmux or none.
    Resolved per call — do not cache it globally, clients differ.
} -hidden str kak_ide_mux

define-command -hidden kak-ide-mux-detect %{
    set-option global kak_ide_mux %sh{
        if [ -n "${kak_client_env_WEZTERM_PANE:-}" ] && command -v wezterm >/dev/null 2>&1; then
            printf 'wezterm'
        elif [ -n "${kak_client_env_TMUX:-}" ]; then
            printf 'tmux'
        else
            printf 'none'
        fi
    }
}

define-command -hidden kak-ide-mux-guard %{
    kak-ide-mux-detect
    evaluate-commands %sh{
        [ "$kak_opt_kak_ide_mux" = none ] &&
            printf "fail 'kak-ide: no multiplexer — run Kakoune inside wezterm or tmux'\n"
    }
}

define-command kak-ide-mux-status -docstring %{
    kak-ide-mux-status: report which multiplexer backend this client drives
} %{
    kak-ide-mux-detect
    evaluate-commands %sh{
        case "$kak_opt_kak_ide_mux" in
            wezterm) detail="pane ${kak_client_env_WEZTERM_PANE}" ;;
            tmux)    detail="pane ${kak_client_env_TMUX_PANE:-?}" ;;
            *)       detail="start Kakoune inside wezterm or tmux" ;;
        esac
        printf 'info -title %%{kak-ide mux} %%{backend:   %s\n%s\nwindowing: %s}\n' \
            "$kak_opt_kak_ide_mux" "$detail" "${kak_opt_windowing_module:-(none)}"
    }
}

# ─── Sized panels ────────────────────────────────────────────────────────────
#
# kak-ide-mux-panel <right|below|left|above> <percent> <shell-command>
#
# Runs <shell-command> via `sh -c` in a new pane of the given size. Kakoune's
# `terminal` covers the unsized case; this exists only because neither the
# wezterm nor the tmux module accepts a size percentage.

define-command -hidden -params 3 kak-ide-mux-panel %{
    kak-ide-mux-guard
    evaluate-commands %sh{
        dir="${kak_buffile%/*}"
        [ -d "$dir" ] || dir="${kak_client_env_PWD:-$PWD}"

        case "$kak_opt_kak_ide_mux" in
            wezterm)
                case "$1" in
                    right) side=--right ;;
                    below) side=--bottom ;;
                    left)  side=--left ;;
                    above) side=--top ;;
                    *)     printf "fail 'kak-ide-mux-panel: bad direction %%{%s}'\n" "$1"; exit ;;
                esac
                wezterm cli split-pane "$side" --percent "$2" \
                    --pane-id "$kak_client_env_WEZTERM_PANE" \
                    --cwd "$dir" -- sh -c "$3" >/dev/null 2>&1
                ;;
            tmux)
                case "$1" in
                    right) axis=-h; before= ;;
                    below) axis=-v; before= ;;
                    left)  axis=-h; before=-b ;;
                    above) axis=-v; before=-b ;;
                    *)     printf "fail 'kak-ide-mux-panel: bad direction %%{%s}'\n" "$1"; exit ;;
                esac
                TMUX="$kak_client_env_TMUX" tmux split-window \
                    "$axis" $before -p "${2%%%*}" \
                    -t "${kak_client_env_TMUX_PANE}" -c "$dir" \
                    sh -c "$3" >/dev/null 2>&1
                ;;
        esac
    }
}

# ─── Directional focus ───────────────────────────────────────────────────────
#
# Builtin `focus` takes a Kakoune client name; there is no way to say "the pane
# to my left". Both backends can, so go to them directly.

define-command -hidden -params 1 kak-ide-mux-focus %{
    kak-ide-mux-guard
    evaluate-commands %sh{
        case "$kak_opt_kak_ide_mux" in
            wezterm)
                case "$1" in
                    left)  d=Left ;; down) d=Down ;; up) d=Up ;; right) d=Right ;;
                    *) printf "fail 'kak-ide-mux-focus: bad direction %%{%s}'\n" "$1"; exit ;;
                esac
                wezterm cli activate-pane-direction \
                    --pane-id "$kak_client_env_WEZTERM_PANE" "$d" >/dev/null 2>&1
                ;;
            tmux)
                case "$1" in
                    left)  d=-L ;; down) d=-D ;; up) d=-U ;; right) d=-R ;;
                    *) printf "fail 'kak-ide-mux-focus: bad direction %%{%s}'\n" "$1"; exit ;;
                esac
                TMUX="$kak_client_env_TMUX" tmux select-pane "$d" \
                    -t "${kak_client_env_TMUX_PANE}" >/dev/null 2>&1
                ;;
        esac
    }
}

# ─── Killing and zooming ─────────────────────────────────────────────────────

define-command -hidden kak-ide-mux-kill-others %{
    kak-ide-mux-guard
    evaluate-commands %sh{
        case "$kak_opt_kak_ide_mux" in
            wezterm)
                # wezterm has no `kill -a`: walk its pane inventory and kill
                # every pane sharing this tab except the current one.
                # Parse per record (split on the closing brace), not per line:
                # wezterm emits tab_id before pane_id, so a field-order-
                # dependent scan would compare against the previous record
                # and miss panes in other tabs. The record separator is
                # written as the octal escape \175 so that Kakoune's %{...}
                # brace counting stays balanced.
                me="$kak_client_env_WEZTERM_PANE"
                inv=$(wezterm cli list --format json 2>/dev/null |
                      tr -d ' "\n' | tr '\175' '\n')
                [ -n "$inv" ] || exit
                tab=$(printf '%s\n' "$inv" | awk -v me="$me" '{
                          t=""; p="";
                          if (match($0, /tab_id:[0-9]+/))  t=substr($0, RSTART+7, RLENGTH-7);
                          if (match($0, /pane_id:[0-9]+/)) p=substr($0, RSTART+8, RLENGTH-8);
                          if (p==me && t!="") { print t; exit }
                      }')
                [ -n "$tab" ] || exit
                printf '%s\n' "$inv" | awk -v tab="$tab" -v me="$me" '{
                        t=""; p="";
                        if (match($0, /tab_id:[0-9]+/))  t=substr($0, RSTART+7, RLENGTH-7);
                        if (match($0, /pane_id:[0-9]+/)) p=substr($0, RSTART+8, RLENGTH-8);
                        if (t==tab && p!="" && p!=me) print p
                    }' |
                    while read -r victim; do
                        wezterm cli kill-pane --pane-id "$victim" >/dev/null 2>&1
                    done
                ;;
            tmux)
                TMUX="$kak_client_env_TMUX" tmux kill-pane -a \
                    -t "${kak_client_env_TMUX_PANE}" >/dev/null 2>&1
                ;;
        esac
    }
}

# wezterm cli cannot report whether a pane is zoomed, so track it ourselves and
# use the explicit --zoom/--unzoom flags rather than --toggle.
declare-option -hidden bool kak_ide_mux_zoomed false

define-command -hidden kak-ide-mux-zoom-toggle %{
    kak-ide-mux-guard
    evaluate-commands %sh{
        [ "$kak_opt_kak_ide_mux_zoomed" = true ] && want=false || want=true
        case "$kak_opt_kak_ide_mux" in
            wezterm)
                [ "$want" = true ] && flag=--zoom || flag=--unzoom
                wezterm cli zoom-pane --pane-id "$kak_client_env_WEZTERM_PANE" \
                    "$flag" >/dev/null 2>&1
                ;;
            tmux)
                TMUX="$kak_client_env_TMUX" tmux resize-pane -Z \
                    -t "${kak_client_env_TMUX_PANE}" >/dev/null 2>&1
                ;;
        esac
        printf 'set-option global kak_ide_mux_zoomed %s\n' "$want"
    }
}

# ─── Integration points for third-party plugins ──────────────────────────────
#
# fzf.kak truncates `fzf_terminal_command` at the first space
# (rc/fzf.kak: cmd="${kak_opt_fzf_terminal_command%% *} %{${fzfcmd}}"), so the
# option must name exactly one command and take the script as its argument.
#
# fzf.kak builds the whole picker into a script, then waits in the background
# for that script to delete itself and reads the result file. It does not care
# how the script is launched — only that it runs somewhere.

declare-option -docstring %{
    kak_ide_fzf_height: height, in percent of the window, of the bottom panel
    fzf pickers open in
} int kak_ide_fzf_height 40

define-command -hidden -params 1 kak-ide-fzf-term %{
    kak-ide-mux-panel below %opt{kak_ide_fzf_height} %arg{1}
}

# kaktree calls this as `${kak_opt_termcmd} "sh -c '...'"` — one argument.
define-command -hidden -params 1.. kak-ide-termcmd %{
    kak-ide-mux-panel left 25 %arg{1}
}
