# ─────────────────────────────────────────────────────────────────────────────
# Merge — a three-pane conflict view: [ours | base | theirs].
#
# The centre pane is the real working file, conflict markers and all, so edits
# land where git expects them and nothing is lost if the panes are closed. The
# outer panes are read-only scratch buffers holding stages :2 and :3 straight
# from the index, shown for reference while resolving.
#
# Panes are clients of this session (see splits.kak), named via rename-client
# so the sync hook can address them. Scroll sync is a poll: an Idle hook on the
# centre client reads its window_range and scrolls the other two to match.
# Polling rather than rebinding scroll keys, so mouse wheel, search jumps and
# any other cursor motion stay in sync too.
# ─────────────────────────────────────────────────────────────────────────────

declare-option -hidden str kak_ide_merge_file
declare-option -hidden str kak_ide_merge_ours
declare-option -hidden str kak_ide_merge_theirs
declare-option -hidden bool kak_ide_merge_active false
declare-option -hidden str kak_ide_merge_tmpdir

define-command -hidden kak-ide-merge-sync %{
    evaluate-commands %sh{
        [ "$kak_opt_kak_ide_merge_active" = true ] || exit
        # Only the centre client drives the sync; the reference panes must not
        # scroll each other back, which would fight the user and never settle.
        case "$kak_client" in
            "$kak_opt_kak_ide_merge_ours"|"$kak_opt_kak_ide_merge_theirs") exit ;;
        esac
        # window_range is "line column height width"; the first field is the
        # topmost displayed line, 0-based.
        top=${kak_window_range%% *}
        line=$((top + 1))
        for c in "$kak_opt_kak_ide_merge_ours" "$kak_opt_kak_ide_merge_theirs"; do
            [ -n "$c" ] || continue
            printf 'try %%{ evaluate-commands -client %s %%{ execute-keys %sgvt } }\n' \
                "$c" "$line"
        done
    }
}

define-command kak-ide-merge -docstring %{
    kak-ide-merge: open the current conflicted file as [ours | base | theirs]
} %{
    evaluate-commands %sh{
        [ -n "$kak_buffile" ] || {
            printf "fail 'kak-ide-merge: no file in this buffer'\n"; exit; }
        [ -z "$kak_opt_windowing_module" ] &&
            printf "fail 'kak-ide-merge: no windowing module — run Kakoune inside wezterm or tmux'\n" &&
            exit

        dir=$(dirname "$kak_buffile")
        root=$(cd "$dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
        [ -n "$root" ] || {
            printf "fail 'kak-ide-merge: not inside a git repository'\n"; exit; }

        rel=$(printf '%s' "$kak_buffile" | sed "s|^${root}/||")

        # Unmerged paths carry stages 1/2/3; a clean file carries none.
        stages=$(cd "$root" && git ls-files -u -- "$rel" 2>/dev/null | awk '{print $3}' | sort -u)
        case "$stages" in
            *2*) ;;
            *) printf "fail 'kak-ide-merge: %%{%s} has no merge conflict'\n" "$rel"; exit ;;
        esac

        tmp="${TMPDIR:-/tmp}/kak-ide-merge.$$"
        mkdir -p "$tmp" || { printf "fail 'kak-ide-merge: cannot create temp dir'\n"; exit; }
        base_f="$tmp/BASE.$(basename "$rel")"
        theirs_f="$tmp/THEIRS.$(basename "$rel")"

        # Stage 1 (base) is absent in add/add conflicts; leave a marker instead.
        (cd "$root" && git show ":1:$rel" 2>/dev/null) > "$base_f" ||
            printf '(no common ancestor — added on both sides)\n' > "$base_f"
        [ -s "$base_f" ] || printf '(no common ancestor — added on both sides)\n' > "$base_f"
        (cd "$root" && git show ":3:$rel" 2>/dev/null) > "$theirs_f" ||
            printf '(no theirs stage)\n' > "$theirs_f"

        printf 'set-option global kak_ide_merge_file %%{%s}\n' "$kak_buffile"
        printf 'set-option global kak_ide_merge_tmpdir %%{%s}\n' "$tmp"
        printf 'kak-ide-merge-open %%{%s} %%{%s}\n' "$base_f" "$theirs_f"
    }
}

define-command -hidden -params 2 kak-ide-merge-open %{
    # Centre pane keeps the real file. Outer panes are read-only views of the
    # index stages; both are placed to the left/right of it.
    set-option global kak_ide_merge_ours   'kak-ide-merge-ours'
    set-option global kak_ide_merge_theirs 'kak-ide-merge-theirs'

    evaluate-commands %{
        set-option window windowing_placement horizontal
        new %sh{ printf 'rename-client kak-ide-merge-theirs
                         edit! -readonly %%{%s}
                         set-option buffer readonly true
                         try %%{ add-highlighter buffer/ show-whitespaces -only-trailing }' "$2" }
    }
    evaluate-commands %{
        set-option window windowing_placement horizontal
        new %sh{ printf 'rename-client kak-ide-merge-ours
                         edit! -readonly %%{%s}
                         set-option buffer readonly true' "$1" }
    }

    set-option global kak_ide_merge_active true
    hook -group kak-ide-merge global Idle .* %{ kak-ide-merge-sync }
    kak-ide-merge-sync
    echo -markup "{Information}kak-ide: merge view — centre pane is the real file; ,gM to close"
}

define-command kak-ide-merge-close -docstring %{
    kak-ide-merge-close: leave the merge view and close the reference panes
} %{
    set-option global kak_ide_merge_active false
    remove-hooks global kak-ide-merge
    try %{ evaluate-commands -client kak-ide-merge-ours   quit! }
    try %{ evaluate-commands -client kak-ide-merge-theirs quit! }
    set-option global kak_ide_merge_ours ''
    set-option global kak_ide_merge_theirs ''
    evaluate-commands %sh{
        # Delete only the path we recorded, and only if it still looks like the
        # directory this command created: an empty or stray option must never
        # reach rm -rf.
        d="$kak_opt_kak_ide_merge_tmpdir"
        case "$d" in
            */kak-ide-merge.[0-9]*) [ -d "$d" ] && rm -rf "$d" ;;
        esac
        printf "set-option global kak_ide_merge_tmpdir ''\n"
    }
    echo -markup "{Information}kak-ide: merge view closed"
}
