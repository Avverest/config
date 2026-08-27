#!/bin/sh
# kak-ide keymap regression test.
#
# Kakoune's `map` silently overwrites an existing binding, and `kakrc` is
# sourced AFTER kak-ide, so a key kak-ide claims can be taken back with no
# error at all. Bindings have shipped unreachable that way.
#
# `debug mappings` is authoritative — it reports what Kakoune actually resolved
# after every file has loaded. This asserts against that, not against source.

fail=0
# NOTE: `write` is a no-op when the target already exists and the buffer is
# unmodified — `*debug*` counts as unmodified. mktemp CREATES the file, so a
# plain `maps=$(mktemp)` yields an empty dump and every assertion below reports
# "unbound" for keys that are in fact bound. Delete it first.
maps=$(mktemp); rm -f "$maps"

: | kak -ui json -e "
evaluate-commands %{
  debug mappings
  evaluate-commands -buffer *debug* %{ write $maps }
  quit!
}" >/dev/null 2>&1

# Kakoune escapes both the key column and the command text (<minus>, <space>,
# <ret>, <dquote>). Unescaping <space> globally would rewrite the KEY names
# `<space>` and `<a-space>` into literal blanks and make them unmatchable, so
# the key column (up to the first ": ") is left exactly as Kakoune printed it
# and only the command half is unescaped.
norm=$(mktemp); rm -f "$norm"
sed 's/<minus>/-/g; s/<ret>/⏎/g; s/<dquote>/"/g' "$maps" \
  | awk -F': ' 'NR>2 && NF>1 { k=$1; sub(/^[^:]*: /,""); gsub(/<space>/," "); print k": "$0; next } { print }' \
  > "$norm"

want() { # want <mode> <key> <substring-of-command> <label>
    line=$(grep -E "^ \* $1 $2:" "$norm" | head -1)
    if [ -z "$line" ]; then
        printf '  %-44s FAIL (unbound)\n' "$4"; fail=1; return
    fi
    if printf '%s' "$line" | grep -qF "$3"; then
        printf '  %-44s ok\n' "$4"
    else
        printf '  %-44s FAIL (-> %s)\n' "$4" "$(printf '%s' "$line" | cut -d"'" -f2)"; fail=1
    fi
}

dupes() { # dupes <mode> — a key mapped twice in one mode means one was shadowed
    d=$(grep -E "^ \* $1 " "$norm" | sed -E "s/^ \* $1 ([^:]+):.*/\1/" | sort | uniq -d)
    if [ -n "$d" ]; then
        printf '  %-44s FAIL (%s)\n' "no duplicate keys in '$1' mode" "$(echo "$d" | tr '\n' ' ')"; fail=1
    else
        printf '  %-44s ok\n' "no duplicate keys in '$1' mode"
    fi
}

echo "── the leader reaches the menus ─────────────────────────────"
want normal ',' 'enter-user-mode user' ',   leader menu'
want normal '<a-space>' 'drop all but main selection' '<a-space>  drop all but main selection'

echo
echo "── leader bindings survive kakrc (load-order shadowing) ──────"
want user x 'write-quit'                ',x  write & quit'
want user a 'lsp-code-actions'          ',a  code actions'
want user l 'enter-user-mode lsp'       ',l  LSP mode'
want user e 'kaktree-toggle'            ',e  file explorer'
want user f 'fzf-project-files'         ',f  find file in project'
want user t 'tree-sitter'               ',t  tree-sitter mode'
want user s 'enter-user-mode kak-ide-split'    ',s  splits mode'
want user m 'enter-user-mode kak-ide-surround' ',m  surround mode'
dupes user

echo
echo "── submodes are reachable and unshadowed ────────────────────"
want kak-ide-split v 'kak-ide-split-right' 'split v  split right'
want kak-ide-split s 'kak-ide-split-below' 'split s  split below'
dupes kak-ide-split
dupes kak-ide-surround

echo
echo "── structural + unimpaired nav ──────────────────────────────"
want object f 'lsp-object Function' '<a-i>f  function textobject'
want object t 'lsp-object Class'    '<a-i>t  type textobject'
want object c 'comment'             '<a-i>c  comment textobject'
want kak-ide-next c 'git next-hunk'   ']c  next git hunk'
want kak-ide-prev c 'git prev-hunk'   '[c  previous git hunk'
want kak-ide-next d 'lsp-find-error'  ']d  next diagnostic'
want kak-ide-next f 'lsp-next-function' ']f  next function'

rm -f "$maps" "$norm"
echo
[ $fail -eq 0 ] && echo "PASS" || echo "FAIL"
exit $fail
