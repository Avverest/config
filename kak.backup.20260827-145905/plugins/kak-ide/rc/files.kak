
# ─────────────────────────────────────────────────────────────────────────────
# File manager: yazi in a full-screen pane, rooted at the project.
#
# wezterm cannot hand back a pane's stdout, so the selection travels through
# --chooser-file. A background poll waits for yazi to exit, then feeds `edit`
# commands into this session with `kak -p`. This is the same shape fzf.kak uses.
# ─────────────────────────────────────────────────────────────────────────────

define-command kak-ide-files -docstring %{
    kak-ide-files: browse the project in yazi and open the selected file(s)
} %{
    kak-ide-mux-guard
    evaluate-commands %sh{
        if ! command -v yazi >/dev/null 2>&1; then
            printf "fail 'kak-ide-files: yazi not found on PATH'\n"
            exit
        fi

        eval "$kak_opt_kak_ide_root_sh"

        tmp=$(mktemp -d "${TMPDIR:-/tmp}"/kak-ide-files.XXXXXX)
        chooser="$tmp/chosen"
        marker="$tmp/running"
        : > "$marker"

        # `rm marker` is what tells the watcher below that yazi has exited.
        script="$tmp/run"
        {
            printf '#!%s\n' "$(command -v sh)"
            printf 'yazi --chooser-file %s %s\n' "$chooser" "$root"
            printf 'rm -f %s\n' "$marker"
        } > "$script"
        chmod 755 "$script"

        (
            while [ -e "$marker" ]; do sleep 0.1; done
            if [ -s "$chooser" ]; then
                while IFS= read -r file; do
                    [ -n "$file" ] || continue
                    printf "evaluate-commands -client %s %%{ edit -existing '%s' }\n" \
                        "$kak_client" "$file"
                done < "$chooser" | kak -p "$kak_session"
            fi
            rm -rf "$tmp"
        ) > /dev/null 2>&1 < /dev/null &

        printf 'kak-ide-fzf-term %%{%s}\n' "$script"
    }
}
