#!/bin/sh
# kak-ide keymap regression test — plan Section 8 / Phase 6.
#
# Kakoune's `map` silently overwrites an existing binding, and `kakrc` is
# sourced AFTER kak-ide, so a key kak-ide claims can be taken back without any
# error. Two such shadowings shipped undetected before this test existed:
#
#   ,x   kak-ide claimed it for diagnostics; kakrc's :write-quit won  -> moved to ,D
#   <space>f in the kak-ide mode was mapped twice in one file; the second won
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

echo "── Section 8 goto table ──────────────────────────────────────"
want goto d 'lsp-definition'        'gd  definition'
want goto D 'lsp-declaration'       'gD  declaration'
want goto y 'lsp-type-definition'   'gy  type definition'
want goto r 'lsp-references'        'gr  references'
want goto i 'lsp-implementation'    'gi  implementation'
want goto f 'kak-ide-goto-file'     'gf  file / import under cursor'

echo
echo "── the leader is reachable ──────────────────────────────────"
# A mode's bindings are dead weight if no key enters the mode. Asserting the
# contents of 'kak-ide'/'user' says nothing about whether any key opens them —
# kakrc's `,` leader is a single `map` and is currently commented out, so
# <space> (via kak-ide-keymap-helix-enable) is the only way in.
leader_ok=no
grep -qE "^ \* normal <space>: ': enter-user-mode kak-ide" "$norm" && leader_ok=yes
grep -qE "^ \* normal ,:" "$norm" && leader_ok=yes
if [ "$leader_ok" = yes ]; then
    printf '  %-44s ok\n' "a leader key reaches the IDE bindings"
else
    printf '  %-44s FAIL (neither <space> nor , is bound)\n' "a leader key reaches the IDE bindings"; fail=1
fi

# Kakoune's <space> must not simply vanish when it is taken as the leader.
# Matched on the docstring: the command it maps to is the literal key `<space>`,
# which the normalizer above turns into a blank and cannot be matched on.
want normal '<a-space>' 'drop all but main selection' '<a-space>  drop all but main selection'

echo
echo "── leader bindings survive kakrc (load-order shadowing) ──────"
want user D 'kak-ide-picker-diagnostics' ',D  diagnostics picker'
want user x 'write-quit'                 ',x  still kakrc:write-quit'
want user R 'kak-ide-rename'             ',R  rename symbol'
want user a 'lsp-code-actions'           ',a  code actions'
want user g 'kak-ide-picker-changed'     ',g  changed files'
want user t 'tree-sitter'                ',t  tree-sitter mode'

echo
echo "── Helix-parity mode is fully reachable ─────────────────────"
want kak-ide f 'kak-ide-picker-files'    'kak-ide f  file picker (not shadowed)'
want kak-ide b 'kak-ide-picker-buffers'  'kak-ide b  buffers'
want kak-ide s 'kak-ide-picker-symbols'  'kak-ide s  document symbols'
want kak-ide / 'kak-ide-picker-grep'     'kak-ide /  global search'
dupes kak-ide

echo
echo "── structural + unimpaired nav ──────────────────────────────"
want object f 'function'  '<a-i>f  function textobject'
want object t 'class'     '<a-i>t  type textobject'
want object a 'parameter' '<a-i>a  argument textobject'
want object c 'comment'   '<a-i>c  comment textobject'
want kak-ide-next c 'git next-hunk'   ']c  next git hunk'
want kak-ide-prev c 'git prev-hunk'   '[c  previous git hunk'
want kak-ide-next d 'lsp-find-error'  ']d  next diagnostic'
want kak-ide-next C 'search_next'     ']C  next comment'
want kak-ide-prev C 'search_prev'     '[C  previous comment'

rm -f "$maps" "$norm"
echo
[ $fail -eq 0 ] && echo "PASS" || echo "FAIL"
exit $fail
