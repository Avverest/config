#!/bin/sh
# Build the kak-ide test fixture: a real multi-file, multi-language project.
# Plan Section 10 requires exercising commands against a project, not single
# files — root detection, tool detection and (later) import resolution are all
# no-ops on a lone file.
set -e
F="${KAK_IDE_FIXTURE:-/tmp/kakide-fixture}"
rm -rf "$F"; mkdir -p "$F/src" "$F/rs/src" "$F/sub"
cd "$F"; git init -q .

echo '{ "name": "kakide-fixture", "version": "1.0.0", "type": "module" }' > package.json
cat > tsconfig.json <<'EOF'
{ "compilerOptions": { "target": "ES2022", "jsx": "react-jsx", "baseUrl": ".",
  "paths": { "@app/*": ["src/*"] }, "moduleResolution": "bundler", "strict": true } }
EOF
cat > biome.json <<'EOF'
{ "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2 },
  "linter": { "enabled": true } }
EOF

# computeTotal is imported from 3 files — the multi-file rename regression target.
cat > src/util.ts <<'EOF'
export function computeTotal(items: number[]): number {
  return items.reduce((a, b) => a + b, 0);
}
EOF
cat > src/index.ts <<'EOF'
import { computeTotal } from "./util";
const total = computeTotal([1, 2, 3]);
console.log(total);
EOF
cat > src/Button.tsx <<'EOF'
import { computeTotal } from "./util";

export function Button({ values }: { values: number[] }) {
  return <button className="btn">{computeTotal(values)}</button>;
}
EOF
cat > src/App.jsx <<'EOF'
import { Button } from "./Button";

export default function App() {
  return <div className="app"><Button values={[1, 2]} /></div>;
}
EOF
echo 'export const greet = (name) => `hello ${name}`;' > src/legacy.js
cat > src/typeerr.ts <<'EOF'
export function addNums(a: number, b: number): number {
  return a + b;
}
const bad: string = addNums(1, 2);
export const unusedThing = bad;
EOF
echo '.btn { color: rebeccapurple; padding: 4px; }' > styles.css
cat > index.html <<'EOF'
<!doctype html>
<html><head><link rel="stylesheet" href="styles.css"></head>
<body><script type="module" src="src/index.ts"></script></body></html>
EOF
cat > init.lua <<'EOF'
local M = {}
function M.setup(opts) return opts or {} end
return M
EOF
echo '{"a":1,   "b":  2}' > sub/t.json

cat > rs/Cargo.toml <<'EOF'
[package]
name = "fixture"
version = "0.1.0"
edition = "2021"
EOF
cat > rs/src/main.rs <<'EOF'
mod err;

fn compute_total(items: &[i32]) -> i32 { items.iter().sum() }

fn main() {
    println!("{}", compute_total(&[1, 2, 3]));
    err::demo();
}
EOF
cat > rs/src/err.rs <<'EOF'
pub fn demo() {
    let x: i32 = "not a number";
    println!("{}", x);
}
EOF

# A .gitignore'd file, so global-search/replace can be checked for honouring it.
echo "node_modules/" > .gitignore
mkdir -p node_modules
echo 'export const ignored = "must not be searched";' > node_modules/ignored.ts

echo "fixture built at $F"
