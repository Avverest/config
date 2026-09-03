declare-option -docstring 'каталоги со сниппетами: подкаталог на filetype' \
    str-list snippets_directories

define-command -override -hidden snippets-load-filetype %{
    set-option window snippets
    evaluate-commands %sh{
        ft="$kak_opt_filetype"
        [ -z "$ft" ] && exit 0

        eval set -- "$kak_quoted_opt_snippets_directories"
        [ $# -eq 0 ] && exit 0

        printf 'set-option window snippets '

        for dir do
            [ -d "$dir" ] || continue
            for sub in "$dir"/*; do
                [ -d "$sub" ] || continue
                name="${sub##*/}"
                case "$name" in
                    "("*")")
                        inner="${name#\(}"
                        inner="${inner%\)}"
                        match=0
                        OLDIFS=$IFS
                        IFS='|'
                        for alt in $inner; do
                            [ "$alt" = "$ft" ] && match=1
                        done
                        IFS=$OLDIFS
                        [ "$match" -eq 1 ] || continue
                        ;;
                    *)
                        [ "$name" = "$ft" ] || continue
                        ;;
                esac

                for f in "$sub"/*; do
                    [ -f "$f" ] || continue
                    base="${f##*/}"
                    case "$base" in
                        *" - "*)
                            trigger="${base%% - *}"
                            desc="${base#* - }"
                            ;;
                        *)
                            trigger="$base"
                            desc="$base"
                            ;;
                    esac
                    KAK_SNIP_TRIG="$trigger" KAK_SNIP_DESC="$desc" \
                        awk -f "$kak_config/snippets-awk.awk" "$f"
                done
            done
        done
        printf '\n'
    }
}

hook global WinSetOption filetype=.* snippets-load-filetype
hook global WinCreate .* snippets-load-filetype
