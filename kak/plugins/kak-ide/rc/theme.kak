# Theme selection, and persistence of it across restarts.
#
# `:colorscheme` only affects the running session — Kakoune has no notion of a
# saved theme. `kak-ide-theme` therefore writes the chosen name to
# `theme.conf`, which `kakrc` sources at startup, so the choice survives a
# restart without any process rewriting `kakrc` itself.

declare-option -docstring "file holding the persisted colorscheme name" \
    str kak_ide_theme_file "%val{config}/theme.conf"

define-command -override kak-ide-theme-save -params 1 \
    -docstring "kak-ide-theme-save <name>: persist <name> as the startup theme" %{
    nop %sh{
        printf 'colorscheme %s\n' "$1" > "$kak_opt_kak_ide_theme_file"
    }
}

define-command -override kak-ide-theme -params 1 \
    -shell-script-candidates %{
        for d in "$kak_config/colors" "$kak_runtime/colors"; do
            [ -d "$d" ] && for f in "$d"/*.kak; do
                [ -e "$f" ] || continue
                f=${f##*/}
                printf '%s\n' "${f%.kak}"
            done
        done | sort -u
    } \
    -docstring "kak-ide-theme <name>: apply <name> and persist it" %{
    colorscheme %arg{1}
    kak-ide-theme-save %arg{1}
    echo -markup "{Information}theme: %arg{1}"
}

# Interactive picker. Uses fzf when the pane bridge is available, so the list
# is searchable; otherwise falls back to the completing `:` prompt above.
define-command -override kak-ide-theme-pick \
    -docstring "pick a colorscheme interactively (fzf) and persist it" %{
    evaluate-commands %sh{
        if command -v fzf >/dev/null 2>&1; then
            printf '%s\n' 'kak-ide-theme-pick-fzf'
        else
            printf '%s\n' 'prompt theme: %{ kak-ide-theme %val{text} }'
        fi
    }
}

define-command -override -hidden kak-ide-theme-pick-fzf %{
    evaluate-commands %sh{
        tmp=$(mktemp -d "${TMPDIR:-/tmp}"/kak-ide-theme.XXXXXX)
        chosen="$tmp/chosen"
        marker="$tmp/running"
        : > "$marker"

        script="$tmp/run"
        {
            printf '#!%s\n' "$(command -v sh)"
            printf 'for d in %s %s; do\n' \
                "'$kak_config/colors'" "'$kak_runtime/colors'"
            printf '  [ -d "$d" ] || continue\n'
            printf '  for f in "$d"/*.kak; do\n'
            printf '    [ -e "$f" ] || continue\n'
            printf '    f=${f##*/}\n'
            printf '    printf "%%s\\n" "${f%%.kak}"\n'
            printf '  done\n'
            printf 'done | sort -u | fzf --prompt="theme> " --preview-window=hidden > %s\n' \
                "'$chosen'"
            printf 'rm -f %s\n' "$marker"
        } > "$script"
        chmod 755 "$script"

        (
            while [ -e "$marker" ]; do sleep 0.1; done
            if [ -s "$chosen" ]; then
                name=$(head -n 1 "$chosen")
                [ -n "$name" ] && printf "evaluate-commands -client %s %%{ kak-ide-theme %s }\n" \
                    "$kak_client" "$name" | kak -p "$kak_session"
            fi
            rm -rf "$tmp"
        ) > /dev/null 2>&1 < /dev/null &

        printf 'kak-ide-fzf-term %%{%s}\n' "$script"
    }
}
