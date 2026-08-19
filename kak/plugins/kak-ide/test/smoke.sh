#!/bin/sh
# kak-ide smoke test — plan Section 10.
#
# Opens one file per target language in a real Kakoune client and reports what
# resolved: filetype, tree-sitter language, languageId, indent, comment token,
# formatter/linter, and (with --lsp) whether a language server attached and
# produced diagnostics.
#
#   ./smoke.sh              # fast: config resolution only
#   ./smoke.sh --lsp        # also start servers and wait for diagnostics
#
# Exits non-zero if any expectation fails.

FIXTURE="${KAK_IDE_FIXTURE:-/tmp/kakide-fixture}"
WITH_LSP=no
[ "$1" = "--lsp" ] && WITH_LSP=yes
fail=0

probe() { # probe <file> -> "ft|lang|iw|cmt|fmt|lint|root"
    out=$(mktemp)
    : | kak -ui json -e "
        evaluate-commands %{
            echo -to-file $out %sh{
                printf '%s|%s|%s|%s|%s|%s|%s' \
                    \"\$kak_opt_filetype\" \"\$kak_opt_lsp_language_id\" \
                    \"\$kak_opt_indentwidth\" \"\$kak_opt_comment_line\" \
                    \"\$kak_opt_kak_ide_formatter\" \"\$kak_opt_kak_ide_linter\" \
                    \"\${kak_opt_kak_ide_project_root##*/}\"
            }
            quit!
        }" "$1" >/dev/null 2>&1
    cat "$out"; rm -f "$out"
}

check() { # check <file> <expect-ft> <expect-lang> <expect-iw>
    file="$1"; xft="$2"; xlang="$3"; xiw="$4"
    r=$(probe "$file")
    ft=$(echo "$r" | cut -d'|' -f1); lang=$(echo "$r" | cut -d'|' -f2)
    iw=$(echo "$r" | cut -d'|' -f3); fmt=$(echo "$r" | cut -d'|' -f5)
    lint=$(echo "$r" | cut -d'|' -f6); root=$(echo "$r" | cut -d'|' -f7)
    status=ok
    [ "$ft"   = "$xft"   ] || { status="FAIL(ft=$ft want $xft)"; fail=1; }
    [ "$lang" = "$xlang" ] || { status="FAIL(lang=$lang want $xlang)"; fail=1; }
    [ "$iw"   = "$xiw"   ] || { status="FAIL(indent=$iw want $xiw)"; fail=1; }
    [ -n "$root" ]         || { status="FAIL(no project root)"; fail=1; }
    printf '%-14s ft=%-11s lang=%-17s iw=%-2s fmt=%-9s lint=%-6s %s\n' \
        "${file##*/}" "$ft" "$lang" "$iw" "$fmt" "$lint" "$status"
}

lsp_check() { # lsp_check <file> <label> <wait-seconds> <expect-diagnostics yes|no>
    file="$1"; label="$2"; wait="$3"; want="$4"
    sess="kakidesmoke$$"
    dbg=$(mktemp); res=$(mktemp)
    ( sleep $((wait + 20)) ) | kak -ui json -s "$sess" "$file" >/dev/null 2>&1 &
    kpid=$!
    sleep "$wait"
    # One command per batch: Kakoune aborts the remaining commands in a batch
    # when one fails, and `*debug*` does not exist until something logs to it.
    kak -p "$sess" <<KAKEOF 2>/dev/null
try %{ evaluate-commands -buffer *debug* %{ write $dbg } }
KAKEOF
    kak -p "$sess" <<KAKEOF 2>/dev/null
evaluate-commands -client client0 %{ echo -to-file $res %sh{ printf '%s %s' "\$kak_opt_lsp_diagnostic_error_count" "\$kak_opt_lsp_diagnostic_warning_count" } }
KAKEOF
    sleep 2
    errs=$(cut -d' ' -f1 "$res" 2>/dev/null); warns=$(cut -d' ' -f2 "$res" 2>/dev/null)
    # grep -c already prints 0 on no match; a `|| echo 0` would print it twice.
    started=$(grep -c 'Starting language server' "$dbg" 2>/dev/null); started=${started:-0}
    # If the debug buffer was empty, fall back to asking the OS.
    [ "$started" -eq 0 ] && started=$(pgrep -f 'kak-lsp' >/dev/null 2>&1 && echo 1 || echo 0)
    crashed=$(grep -c 'crashed' "$dbg" 2>/dev/null); crashed=${crashed:-0}
    status=ok
    [ "$started" -ge 1 ] || { status="FAIL(no server started)"; fail=1; }
    [ "$crashed" -eq 0 ] || { status="FAIL(kak-lsp crashed)"; fail=1; }
    if [ "$want" = yes ] && [ "${errs:-0}" -eq 0 ] && [ "${warns:-0}" -eq 0 ]; then
        status="FAIL(expected diagnostics, got none)"; fail=1
    fi
    printf '%-14s servers=%s errors=%s warnings=%s %s\n' \
        "$label" "$started" "${errs:-?}" "${warns:-?}" "$status"
    kill $kpid 2>/dev/null; wait $kpid 2>/dev/null
    rm -f "$dbg" "$res"
}

[ -d "$FIXTURE" ] || { echo "fixture missing: $FIXTURE (see README)"; exit 2; }

echo "── configuration resolution ──────────────────────────────────"
check "$FIXTURE/src/index.ts"   typescript typescript      2
check "$FIXTURE/src/Button.tsx" tsx        typescriptreact 2
check "$FIXTURE/src/legacy.js"  javascript javascript      2
check "$FIXTURE/src/App.jsx"    jsx        javascriptreact 2
check "$FIXTURE/styles.css"     css        css             2
check "$FIXTURE/index.html"     html       html            2
check "$FIXTURE/init.lua"       lua        lua             2
check "$FIXTURE/rs/src/main.rs" rust       rust            4

if [ "$WITH_LSP" = yes ]; then
    echo
    echo "── language servers ──────────────────────────────────────────"
    lsp_check "$FIXTURE/src/typeerr.ts"  typescript 16 yes
    lsp_check "$FIXTURE/styles.css"      css        10 no
    lsp_check "$FIXTURE/init.lua"        lua        12 no
    lsp_check "$FIXTURE/rs/src/err.rs"   rust       30 yes
fi

echo
echo "── picker core ───────────────────────────────────────────────"
sess="kakidepick$$"
kak -d -s "$sess" >/dev/null 2>&1 &
sleep 3
res=$(mktemp); rm -f "$res"
for c in kak-ide-picker-files kak-ide-picker-files-cwd kak-ide-picker-buffers \
         kak-ide-picker-grep kak-ide-picker-changed kak-ide-picker-jumps \
         kak-ide-picker-palette kak-ide-picker-last kak-ide-picker-symbols \
         kak-ide-picker-symbols-workspace kak-ide-picker-diagnostics \
         kak-ide-palette-refresh kaktree-toggle tree-sitter-nav; do
    printf "try %%{ alias global __probe %s } catch %%{ echo -to-file %s %s }\n" "$c" "$res" "$c"
done | kak -p "$sess"
for m in kak-ide kak-ide-next kak-ide-prev tree-sitter; do
    printf "try %%{ map global %s <F12> nop; unmap global %s <F12> } catch %%{ echo -to-file %s mode:%s }\n" "$m" "$m" "$res" "$m"
done | kak -p "$sess"
sleep 1
if [ -s "$res" ]; then
    printf 'commands/modes   FAIL(missing: %s)\n' "$(tr '\n' ' ' < "$res")"; fail=1
else
    printf 'commands/modes   all 14 commands and 4 user modes present  ok\n'
fi
rm -f "$res"

# The palette has to build its own index; verify it is non-trivial and clean.
printf 'kak-ide-palette-refresh\n' | kak -p "$sess"; sleep 3
cache="$HOME/.config/kak/.kak-ide-palette"
n=$(wc -l < "$cache" 2>/dev/null); n=${n:-0}
junk=$(grep -cE '^-|[[:space:]]' "$cache" 2>/dev/null); junk=${junk:-0}
st=ok
[ "$n" -gt 200 ] || { st="FAIL(index too small: $n)"; fail=1; }
[ "$junk" -eq 0 ] || { st="FAIL($junk malformed entries)"; fail=1; }
printf 'palette index    %s entries, %s malformed  %s\n' "$n" "$junk" "$st"
printf 'quit!\n' | kak -p "$sess" 2>/dev/null

echo
if [ "$fail" -eq 0 ]; then echo "PASS"; else echo "FAIL"; fi
exit $fail
