#!/bin/sh
# kak-ide refactor regression tests — plan Section 10.
#
#   "Multi-file rename regression test: a fixture project (e.g. a TS function
#    imported and called from 3+ files) with an automated check that after
#    rename, grep -r for the old name returns nothing and the new name appears
#    in the expected N locations."
#
#   "Global search/replace regression test: fixture with matches across multiple
#    files and at least one file that should be excluded via .gitignore,
#    verifying it's skipped."
#
#   ./refactor.sh            # find/replace only (fast, no LSP)
#   ./refactor.sh --rename   # also the LSP multi-file rename (slow, needs vtsls)
set -u
FIXTURE="${KAK_IDE_FIXTURE:-/tmp/kakide-fixture}"
HELPER="$(cd "$(dirname "$0")/../bin" && pwd)/kak-ide-replace"
fail=0
restore() { (cd "$FIXTURE" && git checkout -- . >/dev/null 2>&1); }

[ -d "$FIXTURE" ] || { echo "fixture missing: $FIXTURE — run ./make-fixture.sh"; exit 2; }
[ -x "$HELPER" ]  || { echo "helper missing: $HELPER"; exit 2; }

check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then printf '  %-46s ok\n' "$1"
    else printf '  %-46s FAIL (got %s, want %s)\n' "$1" "$2" "$3"; fail=1; fi
}

echo "── project-wide find & replace ───────────────────────────────"
restore
check "discovery finds all 3 files" \
    "$("$HELPER" files "$FIXTURE" 'computeTotal' | wc -l | tr -d ' ')" 3

# .gitignore: node_modules/ignored.ts contains 'ignored' and must be skipped.
check ".gitignore'd file excluded" \
    "$("$HELPER" files "$FIXTURE" 'must not be searched' | wc -l | tr -d ' ')" 0

check "preview writes nothing to disk" \
    "$("$HELPER" preview "$FIXTURE" 'computeTotal' 'X' >/dev/null 2>&1; grep -rl computeTotal "$FIXTURE/src" | wc -l | tr -d ' ')" 3

# Backreferences: rewrite `export function NAME(` -> `export function fn_NAME(`
# and confirm the captured name really landed in the output.
bt=$("$HELPER" preview "$FIXTURE" 'export function (\w+)\(' 'export function fn_$1(' 2>/dev/null |
     grep -c '^+export function fn_computeTotal(')
check "backreferences expand (\$1)" "$bt" 1

# replacement must never be evaluated as code
rm -f /tmp/KAKIDE_PWNED
printf 'let a = MARKER;\n' > "$FIXTURE/src/_evaltest.ts"
"$HELPER" preview "$FIXTURE" 'MARKER' '@{[ system("touch /tmp/KAKIDE_PWNED") ]}' >/dev/null 2>&1
check "replacement is not eval'd" \
    "$([ -e /tmp/KAKIDE_PWNED ] && echo VULNERABLE || echo safe)" "safe"
rm -f "$FIXTURE/src/_evaltest.ts" /tmp/KAKIDE_PWNED

"$HELPER" apply "$FIXTURE" 'computeTotal' 'computeSum' >/dev/null 2>&1
check "apply: old name gone"      "$(grep -rn computeTotal "$FIXTURE/src" 2>/dev/null | wc -l | tr -d ' ')" 0
check "apply: new name in 5 spots" "$(grep -rn computeSum  "$FIXTURE/src" 2>/dev/null | wc -l | tr -d ' ')" 5
check "apply: .gitignore'd file untouched" \
    "$(grep -c 'must not be searched' "$FIXTURE/node_modules/ignored.ts" 2>/dev/null)" 1
restore

if [ "${1:-}" = "--rename" ]; then
    echo
    echo "── LSP multi-file rename (§7.1) ──────────────────────────────"
    restore
    sess="kakiderename$$"
    ( sleep 70 ) | kak -ui json -s "$sess" "$FIXTURE/src/util.ts" >/dev/null 2>&1 &
    sleep 18   # let the TS server index the project
    printf 'evaluate-commands -client client0 %%{ execute-keys "gg16l" }\n' | kak -p "$sess" 2>/dev/null
    sleep 1
    printf 'evaluate-commands -client client0 %%{ lsp-rename computeSum }\n' | kak -p "$sess" 2>/dev/null
    sleep 8
    # MEASURED behaviour, not assumed: kakoune-lsp applies the edit in-memory
    # for the current buffer, but writes every other affected file straight to
    # disk. So immediately after the rename, only the file we renamed FROM still
    # holds the old name on disk. This asserts that reality — if a future
    # kakoune-lsp makes the whole edit reviewable, this test will fail loudly and
    # the README's warning can come out.
    on_disk_current=$(grep -c computeTotal "$FIXTURE/src/util.ts" 2>/dev/null)
    on_disk_others=$(cat "$FIXTURE/src/index.ts" "$FIXTURE/src/Button.tsx" 2>/dev/null | grep -c computeTotal)
    check "current buffer NOT written (reviewable)"  "$on_disk_current" 1
    check "other files ARE written to disk (upstream)" "$on_disk_others" 0
    check "other files already renamed on disk" \
        "$(cat "$FIXTURE/src/index.ts" "$FIXTURE/src/Button.tsx" 2>/dev/null | grep -c computeSum)" 4

    printf 'write-all\n' | kak -p "$sess" 2>/dev/null
    sleep 3
    check "after write-all: old name gone"       "$(grep -rn computeTotal "$FIXTURE/src" 2>/dev/null | wc -l | tr -d ' ')" 0
    check "after write-all: new name in 5 spots" "$(grep -rn computeSum  "$FIXTURE/src" 2>/dev/null | wc -l | tr -d ' ')" 5
    pkill -f "kak -ui json -s $sess" 2>/dev/null
    restore
fi

echo
if [ "$fail" -eq 0 ]; then echo "PASS"; else echo "FAIL"; fi
exit $fail
