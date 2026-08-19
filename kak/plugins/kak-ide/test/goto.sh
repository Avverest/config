#!/bin/sh
# kak-ide import-resolution regression tests — plan Section 10:
#   "Import resolution regression tests per language: relative imports,
#    aliased/path-mapped imports (TS), module-tree imports (Rust mod),
#    require (Lua), asset refs (HTML/CSS)."
set -u
FIXTURE="${KAK_IDE_FIXTURE:-/tmp/kakide-fixture}"
R="$(cd "$(dirname "$0")/../bin" && pwd)/kak-ide-resolve"
fail=0
[ -d "$FIXTURE" ] || { echo "fixture missing: $FIXTURE — run ./make-fixture.sh"; exit 2; }
[ -x "$R" ] || { echo "resolver missing: $R"; exit 2; }

# fixtures this test needs beyond the base set
mkdir -p "$FIXTURE/src/widgets"
[ -f "$FIXTURE/src/widgets/index.ts" ] || echo 'export const W = 1;' > "$FIXTURE/src/widgets/index.ts"
[ -f "$FIXTURE/theme.css" ] || echo '.t { color: red; }' > "$FIXTURE/theme.css"
[ -f "$FIXTURE/main.css" ]  || printf '@import "theme.css";\n' > "$FIXTURE/main.css"

t() { # t <label> <buffile> <filetype> <line> <expected-basename|-none->
    got=$("$R" "$FIXTURE" "$2" "$3" "$4" 2>/dev/null | head -1)
    base=${got##*/}
    [ -z "$got" ] && base='-none-'
    if [ "$base" = "$5" ]; then printf '  %-44s ok\n' "$1"
    else printf '  %-44s FAIL (got %s, want %s)\n' "$1" "$base" "$5"; fail=1; fi
}

echo "── import resolution ─────────────────────────────────────────"
# TypeScript / JavaScript
t "TS relative import"        "$FIXTURE/src/index.ts"   typescript 'import { computeTotal } from "./util";'   util.ts
t "TS path alias (@app/*)"    "$FIXTURE/src/index.ts"   typescript 'import { computeTotal } from "@app/util";' util.ts
t "TS directory index"        "$FIXTURE/src/index.ts"   typescript 'import { W } from "./widgets";'            index.ts
t "TS prefers .ts over .js"   "$FIXTURE/src/index.ts"   typescript 'import x from "./util";'                   util.ts
t "TSX relative import"       "$FIXTURE/src/Button.tsx" tsx        'import { computeTotal } from "./util";'    util.ts
t "JSX relative import"       "$FIXTURE/src/App.jsx"    jsx        'import { Button } from "./Button";'        Button.tsx
t "bare specifier -> LSP"     "$FIXTURE/src/index.ts"   typescript 'import react from "react";'                -none-

# Rust
t "Rust mod declaration"      "$FIXTURE/rs/src/main.rs" rust 'mod err;'                  err.rs
t "Rust pub mod"              "$FIXTURE/rs/src/main.rs" rust 'pub mod err;'              err.rs
t "Rust use crate::"          "$FIXTURE/rs/src/main.rs" rust 'use crate::err::demo;'     err.rs
t "Rust use self::"           "$FIXTURE/rs/src/main.rs" rust 'use self::err::demo;'      err.rs
t "Rust external crate->LSP"  "$FIXTURE/rs/src/main.rs" rust 'use serde::Serialize;'     -none-

# Lua
t "Lua require"               "$FIXTURE/init.lua"       lua  'local M = require("init")'  init.lua

# HTML / CSS assets
t "HTML link href"            "$FIXTURE/index.html"     html '<link rel="stylesheet" href="styles.css">'  styles.css
t "HTML script src"           "$FIXTURE/index.html"     html '<script type="module" src="src/index.ts">'  index.ts
t "HTML remote URL ignored"   "$FIXTURE/index.html"     html '<script src="https://cdn.example/x.js">'    -none-
t "CSS @import"               "$FIXTURE/main.css"       css  '@import "theme.css";'                       theme.css
t "CSS url()"                 "$FIXTURE/main.css"       css  '.x { background: url(theme.css); }'         theme.css

echo
if [ "$fail" -eq 0 ]; then echo "PASS"; else echo "FAIL"; fi
exit $fail
