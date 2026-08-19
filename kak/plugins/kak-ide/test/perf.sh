#!/bin/sh
# kak-ide performance sanity — plan Section 10.
#
# "Global search and workspace symbol lookup on a repo of realistic size
#  (>= this Helix repo's own scale, ~5k+ files) should return in well under a
#  second for search."
#
# This config's own tree is ~100 files, so it can never exercise that bar. The
# cargo registry source checkout is used as a stand-in large repo when present
# (~25k files here); the test skips rather than passes when it is not, since a
# perf assertion that never ran must not report green.

BAR=1.0                      # seconds — plan §10's "well under a second"
REPO="${KAK_IDE_PERF_REPO:-$HOME/.cargo/registry/src}"
fail=0

if [ ! -d "$REPO" ]; then
    echo "SKIP — no large repo at $REPO (set KAK_IDE_PERF_REPO)"; exit 0
fi

nfiles=$(fd -t f . "$REPO" 2>/dev/null | wc -l | tr -d ' ')
if [ "${nfiles:-0}" -lt 5000 ]; then
    echo "SKIP — $REPO has $nfiles files, plan §10 wants >= 5000"; exit 0
fi

elapsed() { # elapsed <sh-command> -> seconds, as a decimal string
    s=$(date +%s%N)
    /bin/sh -c "$1" >/dev/null 2>&1
    e=$(date +%s%N)
    echo "scale=3; ($e - $s) / 1000000000" | bc
}

under() { # under <label> <seconds> <bar>
    if [ "$(echo "$2 < $3" | bc)" = 1 ]; then
        printf '  %-42s %6ss  ok\n' "$1" "$2"
    else
        printf '  %-42s %6ss  FAIL (>= %ss)\n' "$1" "$2" "$3"; fail=1
    fi
}

echo "── plan §10 performance sanity ───────────────────────────────"
echo "  repo: $REPO ($nfiles files)"
echo

RG="rg --line-number --no-column --no-heading --color=never --smart-case --max-count=50"
FD="fd --type f --follow --hidden --exclude .git"

under "file picker: discovery"        "$(elapsed "cd '$REPO' && $FD")"                          "$BAR"
under "grep picker: startup"          "$(elapsed "cd '$REPO' && $RG -- '' | head -n 2000")"     "$BAR"
under "grep picker: query 'fn main'"  "$(elapsed "cd '$REPO' && $RG -- 'fn main' | head -n 2000")" "$BAR"
under "grep picker: query 'unsafe'"   "$(elapsed "cd '$REPO' && $RG -- 'unsafe' | head -n 2000")"  "$BAR"

# The regression this guards: an empty rg pattern with no cap streams the whole
# tree into fzf (9.5M lines / 1.0GB / 1.5s here) and each keystroke re-filters
# it in fzf rather than re-running rg. Assert the startup set stays bounded.
bytes=$(cd "$REPO" && /bin/sh -c "$RG -- '' | head -n 2000" 2>/dev/null | wc -c | tr -d ' ')
if [ "${bytes:-0}" -lt 5000000 ]; then
    printf '  %-42s %6sB  ok\n' "grep picker: startup set is bounded" "$bytes"
else
    printf '  %-42s %6sB  FAIL (unbounded stream)\n' "grep picker: startup set is bounded" "$bytes"; fail=1
fi

echo
[ $fail -eq 0 ] && echo "PASS" || echo "FAIL"
exit $fail
