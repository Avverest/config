
# ─────────────────────────────────────────────────────────────────────────────
# Surround — add, delete and replace the delimiters around each selection.
#
# vim-surround needs its own text objects because Vim has none; Kakoune ships
# <a-i>/<a-a>, so this file only implements the three verbs Kakoune lacks.
# Every command is multi-selection native: the delimiter is applied per cursor.
# ─────────────────────────────────────────────────────────────────────────────

# ─── Delimiters ──────────────────────────────────────────────────────────────
#
# A delimiter is whatever you type. Nothing here decides what may wrap what:
# add takes an opener and a closer as two independent strings, so mismatched
# brackets, guillemets, or a doubled asterisk are all equally valid. The only table in this file
# maps a character to Kakoune's *name* for its text object, which delete and
# replace need because Kakoune finds the matching pair, not this code. That
# naming is Kakoune's own (<a-i>B for braces), not a policy imposed here.
#
# Delimiters travel between these commands as single-quoted strings with any
# literal ' doubled. A percent-brace string cannot carry an unpaired bracket:
# Kakoune would treat it as an unterminated block and wait for the closer.

define-command -hidden -params 1 kak-ide-surround-key %{
    evaluate-commands %sh{
        # on-key names some characters instead of reporting them literally, so
        # a typed + arrives as <plus>. Rather than keep a list of those names,
        # ask Kakoune itself: any <name> longer than one character is fed back
        # through execute-keys, which knows every spelling there is.
        case "$1" in
            '<'*'>')
                printf 'kak-ide-surround-key-resolve %%{%s}\n' "$1" ;;
            *)
                printf "set-option window kak_ide_surround_key '%s'\n" \
                    "$(printf '%s' "$1" | sed "s/'/''/g")" ;;
        esac
    }
}

# Types the named key into a scratch buffer and reads back the character it
# produced. Keeps this file free of any table of Kakoune's key names.
define-command -hidden -params 1 kak-ide-surround-key-resolve %{
    evaluate-commands -save-regs 'a' %{
        evaluate-commands -draft %{
            edit -scratch *kak-ide-surround-key*
            execute-keys '%%d'
            execute-keys "i%arg{1}<esc>"
            execute-keys '%%'
            execute-keys '"ay'
        }
        set-option window kak_ide_surround_key %reg{a}
    }
}

define-command -hidden -params 1 kak-ide-surround-counterpart %{
    evaluate-commands %sh{
        # The pairs live in one string, and the brackets are spelled with
        # printf escapes: a literal brace written in shell here would be
        # counted by Kakoune's block parser and would end this %sh early.
        ob=$(printf '\050'); cb=$(printf '\051')   # ( )
        oc=$(printf '\173'); cc=$(printf '\175')   # { }
        os=$(printf '\133'); cs=$(printf '\135')   # [ ]
        oa='<'; ca='>'
        case "$1" in
            "$ob") c="$cb" ;;
            "$cb") c="$ob" ;;
            "$oc") c="$cc" ;;
            "$cc") c="$oc" ;;
            "$os") c="$cs" ;;
            "$cs") c="$os" ;;
            "$oa") c="$ca" ;;
            "$ca") c="$oa" ;;
            *)     c="$1"  ;;
        esac
        printf "set-option window kak_ide_surround_close '%s'\n" \
            "$(printf '%s' "$c" | sed "s/'/''/g")"
    }
}

# Kakoune's object name for a delimiter, for the verbs that must *find* a pair.
# Anything without a named object keeps the character itself: Kakoune treats a
# punctuation character as its own delimiter, so * or | work unaided.
define-command -hidden -params 1 kak-ide-surround-object %{
    evaluate-commands %sh{
        # Same escaping reason as in counterpart: no literal brace may appear
        # in this shell body, or Kakoune's parser ends the block at it.
        ob=$(printf '\050'); cb=$(printf '\051')
        oc=$(printf '\173'); cc=$(printf '\175')
        os=$(printf '\133'); cs=$(printf '\135')
        case "$1" in
            "$ob"|"$cb") obj='b' ;;
            "$oc"|"$cc") obj='B' ;;
            "$os"|"$cs") obj='r' ;;
            '<'|'>')     obj='a' ;;
            '"')         obj='Q' ;;
            "'")         obj='q' ;;
            '`')         obj='g' ;;
            *)           obj="$1" ;;
        esac
        printf "set-option window kak_ide_surround_object '%s'\n" \
            "$(printf '%s' "$obj" | sed "s/'/''/g")"
    }
}

declare-option -hidden str kak_ide_surround_key
declare-option -hidden str kak_ide_surround_object
declare-option -hidden str kak_ide_surround_close

# ─── Add ─────────────────────────────────────────────────────────────────────
#
# Every verb below builds its execute-keys line inside %sh. A delimiter cannot
# be interpolated into a key string directly: %opt{} expands after the keys are
# parsed, so a bracket would arrive as the rotate-selections key instead of as
# the object character. Generating the command text first sidesteps that.

define-command kak-ide-surround-add -params 0..2 -docstring %{
    kak-ide-surround-add [open] [close]: wrap every selection in a delimiter

    With two arguments, wraps in exactly those strings: they are independent,
    so a mismatched pair is as valid as a matching one. With one argument, the
    closer is that character's counterpart, or the character itself. With
    none, reads one keypress and uses it the same way.
} %{
    evaluate-commands %sh{
        q() { printf '%s' "$1" | sed "s/'/''/g"; }
        case $# in
            2) printf "kak-ide-surround-add-impl '%s' '%s'\n" "$(q "$1")" "$(q "$2")" ;;
            1) printf "kak-ide-surround-add-one '%s'\n" "$(q "$1")" ;;
            *) printf 'on-key %%{ kak-ide-surround-add-key "%%val{key}" }\n' ;;
        esac
    }
}

# Splitting this out lets the counterpart land in an option before it is read:
# a %opt written into %sh output would be expanded before the option is set.
define-command -hidden -params 1 kak-ide-surround-add-one %{
    # Every expansion carrying a delimiter is quoted: an unquoted %arg holding
    # a bracket is re-parsed as command syntax instead of passed through.
    kak-ide-surround-counterpart "%arg{1}"
    kak-ide-surround-add-impl "%arg{1}" "%opt{kak_ide_surround_close}"
}

define-command -hidden -params 1 kak-ide-surround-add-key %{
    kak-ide-surround-key "%arg{1}"
    kak-ide-surround-counterpart "%opt{kak_ide_surround_key}"
    kak-ide-surround-add-impl "%opt{kak_ide_surround_key}" "%opt{kak_ide_surround_close}"
}

define-command -hidden -params 2 kak-ide-surround-add-impl %{
    evaluate-commands %sh{
        # A literal < must become <lt> or Kakoune reads it as the start of a
        # key name, and a literal ' must be doubled to survive the key string.
        k() { printf '%s' "$1" | sed -e "s/</<lt>/g" -e "s/'/''/g"; }
        # -itersel: one pair per selection, not one pair around all of them.
        # Appending the closer before inserting the opener keeps offsets valid.
        printf "execute-keys -itersel 'a%s<esc>i%s<esc>'\n" "$(k "$2")" "$(k "$1")"
    }
    # Reselect the whole new pair, so a second add wraps around the first.
    # Only possible when the opener names an object, so failure is silent.
    kak-ide-surround-object "%arg{1}"
    try %{ evaluate-commands -itersel %{ kak-ide-surround-select-outer } }
}

# ─── Delete ──────────────────────────────────────────────────────────────────

define-command kak-ide-surround-delete -params 0..1 -docstring %{
    kak-ide-surround-delete [char]: strip the innermost surrounding delimiter

    The cursor must sit inside the pair, as it must for <a-i> and <a-a>.
} %{
    evaluate-commands %sh{
        if [ -n "$1" ]; then
            printf "kak-ide-surround-delete-impl '%s'\n" "$(printf '%s' "$1" | sed "s/'/''/g")"
        else printf 'on-key %%{ kak-ide-surround-delete-impl "%%val{key}" }\n'
        fi
    }
}

define-command -hidden -params 1 kak-ide-surround-delete-impl %{
    kak-ide-surround-key "%arg{1}"
    kak-ide-surround-object "%opt{kak_ide_surround_key}"
    # evaluate-commands -itersel, not execute-keys -itersel: the yank register
    # is shared between cursors, so without per-cursor scoping every cursor
    # would paste back whatever the last one happened to yank.
    evaluate-commands -itersel -save-regs a %{
        # Reduce to a cursor sitting *inside* the pair. <a-i> searches
        # outward from the selection, so one already spanning the pair would
        # find the next pair out; and collapsing onto a delimiter itself
        # leaves an unpaired character like | with nothing to match.
        execute-keys '<a-;>;l'
        kak-ide-surround-select-inner
        execute-keys %§"ay§
        kak-ide-surround-select-outer
        execute-keys %§"aR§
    }
}

# Selecting through a command keeps the object character out of the key string:
# %opt expands after keys are parsed, so an interpolated bracket would be read
# as the rotate-selections key rather than as an object character.
define-command -hidden kak-ide-surround-select-inner %{
    evaluate-commands %sh{
        printf "execute-keys '<a-i>%s'\n" "$kak_opt_kak_ide_surround_object"
    }
}

define-command -hidden kak-ide-surround-select-outer %{
    evaluate-commands %sh{
        printf "execute-keys '<a-a>%s'\n" "$kak_opt_kak_ide_surround_object"
    }
}

# ─── Replace ─────────────────────────────────────────────────────────────────

define-command kak-ide-surround-replace -params 0..2 -docstring %{
    kak-ide-surround-replace [from] [to]: swap one surrounding delimiter for another

    Without arguments, prompts for both keys in turn.
} %{
    evaluate-commands %sh{
        case $# in
            2) printf "kak-ide-surround-replace-impl '%s' '%s'\n" \
                   "$(printf '%s' "$1" | sed "s/'/''/g")" \
                   "$(printf '%s' "$2" | sed "s/'/''/g")" ;;
            1) printf "on-key %%{ kak-ide-surround-replace-impl '%s' \"%%val{key}\" }\n" \
                   "$(printf '%s' "$1" | sed "s/'/''/g")" ;;
            *) printf 'on-key %%{ kak-ide-surround-replace-outer "%%val{key}" }\n' ;;
        esac
    }
}

define-command -hidden -params 1 kak-ide-surround-replace-outer %{
    # The first key is already known; it is baked in through %sh so that the
    # remaining %val{key} stays unexpanded until on-key actually reads it.
    evaluate-commands %sh{
        from="$(printf '%s' "$1" | sed "s/'/''/g")"
        printf "on-key %%{ kak-ide-surround-replace-impl '%s' \"%%val{key}\" }\n" "$from"
    }
}

define-command -hidden -params 2 kak-ide-surround-replace-impl %{
    # The new delimiters are two independent strings, exactly as in add: the
    # replacement need not be a matching pair, or a pair at all.
    kak-ide-surround-key "%arg{2}"
    kak-ide-surround-counterpart "%opt{kak_ide_surround_key}"
    set-option window kak_ide_surround_to_open  %opt{kak_ide_surround_key}
    set-option window kak_ide_surround_to_close %opt{kak_ide_surround_close}

    kak-ide-surround-key "%arg{1}"
    kak-ide-surround-object "%opt{kak_ide_surround_key}"
    evaluate-commands -itersel -save-regs a %{
        execute-keys '<a-;>;l'
        kak-ide-surround-select-inner
        execute-keys %§"ay§
        kak-ide-surround-select-outer
        kak-ide-surround-rewrap
    }
}

define-command -hidden kak-ide-surround-rewrap %{
    evaluate-commands %sh{
        # No reselect afterwards: <esc> leaves the cursor on the new closing
        # delimiter, which is outside the object <a-a> would look for.
        k() { printf '%s' "$1" | sed -e "s/</<lt>/g" -e "s/'/''/g"; }
        printf "execute-keys 'c%s<c-r>a%s<esc>'\n" \
            "$(k "$kak_opt_kak_ide_surround_to_open")" \
            "$(k "$kak_opt_kak_ide_surround_to_close")"
    }
}

declare-option -hidden str kak_ide_surround_to_open
declare-option -hidden str kak_ide_surround_to_close

# ─── Tags ────────────────────────────────────────────────────────────────────

define-command kak-ide-surround-tag -docstring %{
    kak-ide-surround-tag: wrap every selection in an HTML/XML tag

    Prompts for the tag body, so `div class="x"` opens <div class="x"> and
    closes </div>: attributes are kept on the opener and dropped from the
    closer.
} %{
    prompt 'tag: ' %{
        evaluate-commands %sh{
            # Every literal < must be written <lt>, or Kakoune reads it as the
            # start of a key name and the insert silently does something else.
            name="${kak_text%% *}"
            printf "execute-keys -itersel 'a<lt>/%s><esc>i<lt>%s><esc>'\n" \
                "$name" "$kak_text"
        }
    }
}

define-command kak-ide-surround-delete-tag -docstring %{
    kak-ide-surround-delete-tag: strip the surrounding HTML/XML tags

    Kakoune has no tag text object, so this works on the selection rather than
    on a pair found from the cursor: select the element first (for example with
    %, or with kak-tree-sitter's own tag motions), then run this.
} %{
    # Every literal < must be written <lt> inside a key string.
    execute-keys -itersel 's<lt>[^>]+>|<lt>/[^>]+><ret>d'
}

# ─── Keymap ──────────────────────────────────────────────────────────────────

declare-user-mode kak-ide-surround

define-command kak-ide-keymap-surround-enable -docstring %{
    kak-ide-keymap-surround-enable: bind surround verbs under <space>m

    m rather than s: the s slot on the user mode already opens splits.
} %{
    map global user m ': enter-user-mode kak-ide-surround<ret>' -docstring 'surround…'

    # The three verbs. Each reads the delimiter as the next keypress, so any
    # character works: a pipe wraps in pipes just as a bracket wraps in
    # brackets, with no list of blessed characters anywhere.
    map global kak-ide-surround a ': kak-ide-surround-add<ret>'     -docstring 'add (then any char)'
    map global kak-ide-surround d ': kak-ide-surround-delete<ret>'  -docstring 'delete (then any char)'
    map global kak-ide-surround r ': kak-ide-surround-replace<ret>' -docstring 'replace (then old, new)'

    map global kak-ide-surround t ': kak-ide-surround-tag<ret>'        -docstring 'wrap in HTML tag'
    map global kak-ide-surround T ': kak-ide-surround-delete-tag<ret>' -docstring 'remove HTML tags'

    # One-key shortcuts for the quote characters, each a preset call of the
    # same generic add. They add no capability: every one of them is equally
    # reachable by typing the character itself after a. Brackets get no
    # shortcut because a literal bracket cannot appear in this block at all --
    # Kakoune counts brackets while parsing it, even inside a quoted string,
    # and an unpaired one would end the block early.
    map global kak-ide-surround q %§: kak-ide-surround-add-one "'"<ret>§ -docstring %§wrap in ' '§
    map global kak-ide-surround Q %§: kak-ide-surround-add-one '"'<ret>§ -docstring %§wrap in " "§
    map global kak-ide-surround g %§: kak-ide-surround-add-one '`'<ret>§ -docstring %§wrap in ` `§

    echo -markup "{Information}kak-ide: surround bound to <space>m"
}
