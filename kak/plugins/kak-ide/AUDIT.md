# Phase 0 — Gap audit (verified facts)

Replaces the assumptions in Section 3 of `KAKOUNE-PARITY-PLAN.md` with facts
verified on this machine on 2026-08-19.

## Environment

| Component | Version / path | Notes |
|---|---|---|
| Kakoune | 2026.05.21 (`/opt/homebrew/bin/kak`) | Current release. |
| kakoune-lsp (`kak-lsp`) | **21.0.2** (`/opt/homebrew/bin/kak-lsp`) | Far newer than the plan assumes. |
| kak-tree-sitter | 3.2.2 (`~/.cargo/bin/kak-tree-sitter`) | `ktsctl` 3.2.2 alongside. |
| Grammar/query store | `~/Library/Application Support/kak-tree-sitter/` | macOS path, not `~/.local/share`. |
| Pickers | `fzf.kak` (+ `fzf`, `fd`, `rg`) | `bat` and `sk` absent; `fd`/`rg` present. |
| Explorer | `kaktree` | Installed, unconfigured. |
| Plugin manager | `plug.kak` | Working. |

## Finding 1 — Plan Section 7.1 is already solved upstream

The plan budgets Phase 2 for building multi-file `WorkspaceEdit` application
into `kak-lsp`, and flags it as the one place that might require a **Kakoune
C++ core patch**. This is obsolete. kakoune-lsp 21.0.2 already ships:

- `lsp-rename`, `lsp-rename-prompt` — workspace-wide rename
- `lsp-apply-workspace-edit`, `-request`, `-sync` — multi-file edit application,
  implemented in the Rust daemon (`lsp-send apply-workspace-edit`)
- `lsp-workspace-symbol`, `lsp-workspace-symbol-incr`
- `lsp-inlay-hints-enable`, `lsp-signature-help`, `lsp-auto-signature-help-enable`
- `lsp-snippets-insert`, `lsp-snippets-select-next-placeholders`
- `lsp-code-actions`, `lsp-code-lens`, `lsp-diagnostics`, `lsp-document-symbol`
- `lsp-incoming-calls` / `lsp-outgoing-calls`, `lsp-object`, `lsp-selection-range`

**Consequence:** no core patch, no `kak-lsp` fork. The `[DECISION]` in Section 3
resolves to "do not fork" with no caveat. Phase 2 collapses from *build an
engine* to *configure, bind, and verify*.

## Finding 2 — Config mechanism differs from the plan

The plan describes writing `kak-lsp`'s `servers.toml`. In v21 that file is gone.
Configuration is the per-buffer `lsp_servers` option, holding a TOML table set
from a `BufSetOption filetype=...` hook. `lsp_config`, `lsp_server_configuration`
and `lsp_server_initialization_options` are all deprecated.

kakoune-lsp also ships **built-in defaults for all 7 target languages**
(`lsp-load-default-config`), including a ready-made `lsp_server_biome` option.
The existing `kakrc` *overrides* several of these with weaker configs — notably
`html`, `css` and `lua` lose formatter and validation settings the defaults
provide. That is a regression to fix, not a gap to fill.

## Finding 3 — Tree-sitter coverage was the real gap (now closed)

At audit time only `html, javascript, lua, markdown, typescript` grammars were
installed; **`rust`, `css`, `jsx`, `tsx` were missing entirely** — Rust had no
tree-sitter highlighting at all. Fixed during this phase via
`ktsctl sync rust css jsx tsx`. Current state:

| Language | grammar | highlights | injections | indents | locals | textobjects |
|---|---|---|---|---|---|---|
| rust | yes | yes | yes | yes | yes | **yes** |
| typescript | yes | yes | yes | yes | yes | **yes** |
| tsx | (typescript) | yes | yes | yes | yes | **yes** |
| javascript | yes | yes | yes | yes | yes | **yes** |
| jsx | (javascript) | yes | yes | yes | yes | **yes** |
| lua | yes | yes | yes | yes | — | **yes** |
| css | yes | yes | yes | yes | — | no |
| html | yes | yes | yes | — | — | no |

CSS and HTML have no upstream `textobjects.scm`. Section 2.3's function/class/
argument text objects are therefore unreachable for those two languages via
tree-sitter; `lsp-object` (document symbols) is the fallback.

## Finding 4 — Language server inventory

Present: `rust-analyzer`, `vscode-css-language-server`,
`vscode-html-language-server`, `vscode-eslint-language-server`,
`lua-language-server`, `vscode-json-language-server`.

**`typescript-language-server` was missing** — mandatory requirement 3 (TS/JS)
could not work. Installed during this phase (`npm -g`, v5.3.0). `vtsls` 0.3.0
was already present and remains a drop-in alternative.

Formatters/linters present: `prettier`, `biome`, `eslint`, `stylelint` — so
Section 6.1's detection logic has real tools to resolve to.

Absent and non-blocking: `superhtml` (optional stricter HTML diagnostics),
`bat` (picker previews degrade to `cat`), `deno`.

## Finding 5 — pnpm global bin is not on PATH

`pnpm`'s configured global bin is `~/Library/pnpm/bin`, which is **not** on
PATH; the tools that do resolve (`prettier`, `biome`, `eslint`) live in
`~/Library/pnpm`. New `pnpm add -g` installs will not be visible to Kakoune.
npm's global bin does work. Worth a `pnpm setup` at some point; not blocking.

## Revised phase outlook

| Phase | Plan's estimate | After audit |
|---|---|---|
| 1 Language plumbing | build from scratch | mostly configuration; grammars + tsserver now installed |
| 2 IDE core / multi-file rename | build engine, maybe patch C++ core | **already upstream** — configure, bind, verify |
| 3 Pickers / explorer / goto-file | build | still real work; `fzf.kak` + `kaktree` are partial bases |
| 4 Tree-sitter objects + VCS | extend | queries now present for 6/8; git layer still to build |
| 5 DAP | stretch | unchanged — out of scope unless requested |
| 6 Keymaps | last | unchanged |

---

# Addendum — findings from implementing Phase 1

Discovered while building, not during the initial survey. Each of these
invalidated an assumption in the plan or in the existing config.

## A. kak-tree-sitter's config was never being read

`XDG_CONFIG_HOME` is unset on this machine, so kak-tree-sitter resolves its
config through the platform config dir — `~/Library/Application Support/` on
macOS, not `~/.config/`. The `config.toml` sitting in
`~/.config/kak-tree-sitter/` had no effect, which is why it was byte-identical
to `ktsctl default-config`.

Fixed by replacing it with a minimal override (deltas only, so upstream default
updates are no longer masked) and symlinking the live path to the tracked file:

```
~/Library/Application Support/kak-tree-sitter/config.toml
    -> ~/.config/kak-tree-sitter/config.toml
```

Original preserved as `config.toml.bak-20260819`.

## B. `tsx` was mapped to a grammar that cannot parse JSX

kak-tree-sitter's default config declares `[grammar.typescript] path =
"typescript/src"` and `[language.tsx] grammar = "typescript"`.
`tree-sitter-typescript` ships **two** grammars; `typescript/src` is the one
*without* JSX. Every `<Component />` in a `.tsx` file was therefore parsed as a
comparison operator, and the tsx textobject/injection queries never matched.

Fixed by declaring a separate `[grammar.tsx]` built from `tsx/src` and pointing
`language.tsx` at it. `jsx` needs no equivalent fix — JSX is part of the base
`tree-sitter-javascript` grammar.

## C. `formatcmd` with `%val{buffile}` silently does nothing

Kakoune runs the formatter as `eval "$kak_opt_formatcmd"` **in a shell**
(`rc/tools/format.kak`). A value written as `%{prettier --stdin-filepath
"%val{buffile}"}` is a raw string — `%val{buffile}` is never expanded, and
Prettier receives the literal seven characters `%val{buffile}` as the path,
fails, and `format` discards the output leaving the buffer untouched.

This affected the **pre-existing** config: format-on-save for JS/TS/CSS/HTML/
JSON/YAML/Markdown and Lua had never worked. Fixed in both `kak-ide` (paths
substituted and shell-quoted at set time) and `kakrc` (switched to `"..."`,
which does expand).

## D. Kakoune only exports the `kak_*` variables it can see

A `%sh{}` block only receives the `kak_*` variables whose names appear
literally in the block's text. Shell code stored in an option and `eval`'d
inside `%sh{}` therefore runs with those variables unset. This made project
root detection silently fall back to the server's cwd — every project resolved
to `~/.config`. Fixed by naming the needed variables in the block
(`: "$kak_buffile" "$kak_quoted_opt_..."`).

## E. kakoune-lsp has no `only-features` / `except-features`

Plan §6.1 asks for Biome and ESLint to be attached with Helix's feature
scoping. kakoune-lsp 21 has no such key — the documented server options are
`root`/`root_globs`/`command`/`args`/`single_instance`/`settings`/
`settings_section`/`workspace_did_change_configuration_subsection`/
`experimental`/`symbol_kinds`.

Adapted: lint servers are attached unscoped (diagnostics and code actions from
multiple servers merge, which is the desired behaviour anyway), and formatting
is scoped the way kakoune-lsp actually supports — an explicit `formatcmd`, so
tsserver's built-in formatter never competes with Biome or Prettier.

## F. `typescript-language-server` ships no TypeScript, and the global one is a shim

The server refuses to initialise without a TypeScript installation
("Could not find a valid TypeScript installation"), and that failure **panics
kak-lsp** (`capabilities.rs:417: no entry found for key`), disabling LSP for
the buffer entirely — a single missing dependency took down Biome too.

`npm root -g`'s `typescript` on this machine is a vite-plus shim containing
only `getExePath.js`/`tsc.js` — no `tsserver.js`. The other copies are a stale
pnpm `typescript@4.9.5` and one vendored inside `@vtsls/language-server`
(5.9.3), neither safe to depend on.

Resolved by installing a TypeScript that kak-ide owns, at
`~/.local/share/kak-ide/node_modules/typescript` (pinned to the 5.x line —
`typescript@latest` is now 7.x, which is the Go rewrite and ships no
`tsserver.js`). `tsserver.path` resolves project-local first, this second.

## G. `set-option -add` on `str` does concatenate

Worth recording because it looked like a bug during development and is not:
`set-option -add` on a `str` option appends (`AAA` + `BBB` -> `AAABBB`), so
`tooling.kak` can append a lint server to `lsp_servers` safely.

## Verified state after Phase 1

`plugins/kak-ide/test/smoke.sh --lsp` passes: correct filetype, tree-sitter
language, `languageId`, indent width and resolved formatter/linter for all
eight file types, and a running language server producing real diagnostics for
TypeScript, CSS, Lua and Rust.

## H. vtsls is the better default TypeScript server here

Recorded after the fact: Phase 1 initially installed `typescript-language-server`
because plan §6 names it and kakoune-lsp defaults to it. `vtsls` 0.3.0 was
already installed globally and is the better choice on this machine.

Measured, not assumed:

| | typescript-language-server | vtsls |
|---|---|---|
| Vendors TypeScript | no | **yes (5.9.3)** |
| Works in a project with no `node_modules` | no — refuses to start | **yes** |
| Failure mode when TypeScript is absent | **panics kak-lsp**, disabling LSP for the buffer (incl. Biome) | n/a |
| Install location | `~/.vite-plus/js_runtime/node/24.18.0/bin` | same |
| Diagnostics on the fixture | 1 error, correct | 1 error, correct |

Both live in the *same* version-pinned node prefix, so installing tsls bought
no robustness over the vtsls that was already there — while requiring a third
TypeScript install to work at all.

`kak_ide_ts_server` now defaults to `auto` (prefer vtsls), with a guard that
refuses to hand kak-lsp a `typescript-language-server` config when no
TypeScript can be resolved. Verified by hiding every available TypeScript: all
three settings started vtsls and none crashed.

Difference worth knowing: typescript-language-server auto-detects a workspace
TypeScript, vtsls uses its bundled one unless told otherwise — so kak-ide sets
`typescript.tsdk` when the project pins its own.

---

# Addendum — findings from Phase 3 (pickers) and Phase 4

## I. kak-tree-sitter already binds everything; nothing was reachable

kak-tree-sitter installs **70 maps** at init across the `tree-sitter`,
`tree-sitter-search/-find/-select/-nav-sticky` user modes, *and* maps object mode
directly (`<a-i>f` function, `<a-i>t` class, `<a-i>a` parameter, `<a-i>T` test).
Because it initialises after the LSP object maps in `kakrc`, those tree-sitter
objects already win — the better outcome, since tree-sitter objects are precise
where LSP document symbols are coarse. `kakrc`'s `<a-i>d` diagnostics object is
unaffected.

Nothing was missing except an entry point: no binding entered the `tree-sitter`
mode. Plan Phase 4's "extend kak-tree-sitter for textobject parity" is therefore
almost entirely keymap work, not code.

Real command names, for the record: `tree-sitter-nav <json-direction>`,
`tree-sitter-text-objects <pattern> <mode>`, `tree-sitter-object-text-objects
<pattern>` — not the `tree-sitter-object` shape assumed while drafting.

## J. Git gutter and hunk navigation are native to Kakoune

Plan §3 lists VCS as "Plugins: git.kak, kakoune-vcs, or similar — needs
standardizing". It is already standard: Kakoune ships `rc/tools/git.kak` with
`git show-diff` (populates the `git_diff_flags` gutter), `git next-hunk`,
`git prev-hunk`, `git apply` (reverse-apply a selection = hunk reset), `git
blame`, `git blame-jump`. All unbound.

The one genuine gap: `show-diff` computes the gutter once and never refreshes.
`kak-ide-keymap-git-enable` re-runs it on `WinCreate` and `BufWritePost`.

## K. Kakoune exposes no jumplist and no command list

Two plan items are not implementable at the plugin boundary as written:

- **Jumplist picker** (§2.6) — Kakoune maintains a jumplist for `<c-o>`/`<c-i>`
  but provides no `%val` to read it. `%val{buflist}` and `%val{client_list}`
  exist; a jumplist value does not. Shipped instead: a deduplicated
  recent-locations ring recorded on `WinDisplay`, named for what it is.
- **Command palette** (§2.6) — there is no command enumeration: no `%val`, no
  `debug commands` subcommand (the string in the binary is a false positive),
  and this Homebrew build ships no `doc/pages`. The palette builds its own index
  by scraping `define-command` from `$kak_runtime/rc` and `$kak_config`, unioning
  it with kakoune-lsp's generated commands and a static list of C++ builtins.
  778 entries, verified free of malformed lines by the smoke test.

## L. `map` binds a single key only

Helix's unimpaired bindings (`]c`, `[d`, `]f`) cannot be expressed as
`map global normal ']c'` — Kakoune rejects it with "only a single key can be
mapped". Kakoune leaves `[` and `]` unbound in normal mode and has no bracket-nav
convention, so §8 rule 3 applies: `]`/`[` enter the `kak-ide-next`/`kak-ide-prev`
user modes and the second key selects the target.

## M. kaktree was installed but never loaded

`plugins/kaktree` was present and unreferenced by `kakrc` — the file explorer was
dead weight for the whole life of the config. Now wired. Note that kaktree
declares its options inside `provide-module kaktree`, so a `plug` config block
must `require-module kaktree` before setting any of them, or every
`set-option` fails with "option not found".

---

# Addendum — Phase 2 (refactoring)

## N. Multi-file rename works — and writes to disk without asking

Verified against the fixture: renaming `computeTotal` -> `computeSum` from
`util.ts` correctly updated **5 occurrences across 3 files**, including the
`.tsx`, with zero occurrences of the old name left. Finding 1 stands: no
`kak-lsp` fork and no C++ core patch were needed.

But the *review* half of plan §7.1 is not satisfied, and this corrects an
earlier claim in this document that it was. Measured behaviour:

| File | Result |
|---|---|
| the buffer the rename was issued from | modified in memory, disk untouched — reviewable |
| every other affected file | **written straight to disk**, no confirmation |

In the 3-file fixture, 2 of 3 files were silently rewritten. §7.1 explicitly
asks for "do not silently write to disk … so the user can inspect each file's
diff before a bulk `:write-all`".

**Pre-opening the affected files as buffers does not fix it.** Tested: with all
three files open, the two non-current ones were still written, and their buffers
were reloaded to match (`modified=false`, buffer content == disk content). The
pre-open is at least harmless — a stale buffer plus `:write-all` could otherwise
have reverted the file — but it buys no reviewability.

Satisfying §7.1 properly requires changing how kakoune-lsp applies a
`WorkspaceEdit`; it is not reachable from the plugin boundary. `kak-ide-rename`
therefore reviews *after* the fact via `git diff`, and `kak-ide-rename-check`
warns when the work tree is already dirty, since that is precisely when a
post-hoc diff stops being attributable to the rename.

## O. Find & replace: engine parity matters

`rg`'s default engine is Rust-regex; perl is PCRE. Using the default for
discovery and perl for substitution would let the two disagree (backreferences,
lookaround), and the previewed file set would not match the set that changes.
`rg --pcre2` is available in ripgrep 15.2.0 here, so both halves are PCRE and
the preview is exact.

The replacement string is **not** eval'd. Supporting `$1..$9` via perl's `/ee`
would make a replacement string executable code; group expansion is done
explicitly instead. Covered by a regression test that attempts
`@{[ system("touch /tmp/KAKIDE_PWNED") ]}` and asserts nothing runs.

---

# Addendum — picker preview and splits

## P. fzf preview was broken by a missing `{}`

`fzf.kak` special-cases only the *names* `bat`/`coderay`/`highlight`/`rouge`/
`clp` and otherwise passes `fzf_highlight_command` through verbatim into
`--preview '(<cmd> || cat {}) 2>/dev/null'`. This config fell back to a bare
`cat` when `bat` was absent (it is), producing `cat` with **no argument** —
which reads stdin and renders an empty preview pane. The fallback must be
`cat {}`.

Also fixed alongside it:

- `fzf_preview_pos` was `auto`, which picks a right split or a *top* split from
  the terminal's aspect ratio — so `fzf_preview_width` only applied sometimes.
  Pinned to `right` at `65%`, i.e. 35% list / 65% preview.
- `windowing_placement` defaults to `window`, so fzf opened in a separate
  WezTerm *window*. Replaced with a pane split at 70% of the current pane.

**Verification limit:** this environment allocates no pty (`script` captures 0
bytes even for `echo`), so the fzf TUI cannot be driven headlessly. What is
verified: the shell semantics of both forms (bare `cat` emits nothing; `cat {}`
emits the file), and that fzf 0.74.2 accepts `--preview-window=right:65%:+2-/2`
while rejecting malformed specs. The on-screen result needs a human.

## Q. tmux is not required, for preview or for splits

Preview is pure fzf and independent of tmux — installing tmux would not have
fixed the blank pane above.

The one thing tmux would have provided is fzf.kak's `fzf-vertical`/
`fzf-horizontal`, which hard-code `tmux-terminal-*`. That is plan §7.4's
open-in-split. Since Kakoune has no internal splits either way — a split is a
second client in a second terminal pane — the terminal must supply it, and
`wezterm cli split-pane` already does. Implemented natively as
`kak-ide-open-vsplit`/`-hsplit`, spawning a client on the *same* Kakoune
session so buffers, registers and language servers are shared. No tmux
dependency taken.

---

# Addendum — Phase 3 completion (§7.3 goto-file / imports)

Implemented as `bin/kak-ide-resolve` (filesystem probing per language) plus
`rc/goto.kak` (the Kakoune layer and fallback chain). 18 regression cases in
`test/goto.sh`, covering every language pair Section 10 names.

Resolution order follows §7.3: probe the filesystem first, fall back to
`lsp-definition`, then to Kakoune's native `gf`. The resolver deliberately
returns *nothing* for bare package specifiers and external crates — the server
resolves those correctly into `node_modules` / `~/.cargo/registry`, and guessing
would be worse than deferring. Two of the regression cases assert exactly that
(`import react from "react"`, `use serde::Serialize`).

Three portability bugs worth recording, all found by the tests:

- **BSD `sed` has no `\?` or `\+` in basic regex.** The Rust `mod`/`use`
  patterns silently matched nothing on macOS. Everything now uses `sed -E`.
- **No `realpath(1)` on macOS**, and a resolved candidate may legitimately not
  exist yet, so `./` and `../` are normalised textually rather than by resolving
  against the filesystem.
- **`timeout(1)` does not exist on macOS** — a test that used it appeared to
  pass while actually never running the program under test. Worth remembering:
  a green result from a command that was never executed looks identical to a
  real pass.

`gf` is rebound from Kakoune's native goto-file. §8 rule 4 (Kakoune's binding
wins a conflict) does not apply, because the new behaviour is a superset: the
native path-opening is still the last fallback.

---

# Addendum — Phase 6 (keybinding reconciliation)

## R. `debug mappings` exists — §8 step 1 was solvable after all

Plan §8 step 1 says the current keymap cannot be dumped ("`kak -e 'debug
options'` won't show this — instead diff against Kakoune's `src/normal.cc`").
That is wrong for this build: `debug mappings` is a real subcommand and prints
every mapping in every mode, after all config has loaded. 210 lines here.

This matters beyond convenience. Source-diffing shows what a file *asks* for;
`debug mappings` shows what Kakoune *resolved*. The two differ whenever one map
overwrites another, which is silent in Kakoune — and that silence had already
hidden two live bugs (S below). All Phase 6 assertions are now made against the
resolved keymap, in `test/keymap.sh`.

## S. Two bindings were shadowed and unreachable

Both found by diffing intent against `debug mappings`, neither producing any
error at load:

| Key | Claimed by | Actually resolved to | Cause |
|---|---|---|---|
| `,x` | `keymap.kak` → diagnostics picker | `kakrc`'s `:write-quit` | `kakrc` sources kak-ide at line 162 and binds `,x` at line 361 — **later wins** |
| `<space>f` (kak-ide mode) | file picker | goto-file | mapped twice *within keymap.kak itself*; the later line won |

The `,x` case is the more instructive one: the module's own header comment
asserted that diagnostics lived on `,x` as the resolution of a documented
conflict with `,d`. It had never been reachable. Load order makes any key
kak-ide claims revocable by `kakrc` without warning, so intent-in-source is not
evidence of a binding.

Fixed: diagnostics moved to `,D` (free, and matches Helix's `Space D`), `,x`
left to `kakrc`. The duplicate `<space>f` line removed, restoring the file
picker; `kak-ide-goto-file` remains on `gf` where §8 puts it.

## T. `write` silently no-ops onto an existing file

Cost an hour of chasing a "config regression" that was a broken test harness,
so it is worth recording. `evaluate-commands -buffer *debug* %{ write /path }`
writes nothing if `/path` already exists and the buffer is unmodified — and
`*debug*` is never modified. `mktemp` **creates** its file, so the idiom

    maps=$(mktemp)          # file now exists, empty
    ... write $maps         # no-op

yields an empty dump. Every assertion then reports "unbound" for keys that are
correctly bound: a harness failure that is indistinguishable from a real
config regression by its output alone. `test/keymap.sh` deletes the mktemp file
before writing.

Same family as the `timeout(1)` note in the Phase 3 addendum — a green result
from a command that never ran, and a red result from an assertion that never
saw its input, look exactly like real ones.

## U. Gaps closed in this phase

`gD` (declaration) and `gi` (implementation) were in §8's table but unbound;
`lsp-declaration` and `lsp-implementation` both exist in kakoune-lsp 21 and
Kakoune's goto mode leaves `D` and `i` free, so neither displaced anything.

The **comment text object** (§2.3) was unbound despite being available: every
tree-sitter language installed here that ships `textobjects.scm` — rust,
typescript, tsx, javascript, jsx, lua — defines `@comment.inside`/
`@comment.around`, but kak-tree-sitter's `rc/text-objects.kak` maps only
`f`/`t`/`a`/`T` into object mode and never `c`. Bound here in upstream's own
shape, plus `]C`/`[C` for comment navigation.

Coverage note carried forward from Finding 3: css and html ship no
`textobjects.scm` upstream, so no text object binding applies to them.

## V. A mode's contents say nothing about its reachability

`kakrc`'s `,` leader — a single `map global normal ,` — is commented out, so at
the time Phase 6's bindings were verified present via `debug mappings`, **no key
entered `user` mode at all**. Every `,`-prefixed binding in this config,
including the `,D` diagnostics picker moved there earlier in this phase, was
unreachable. The dump shows a mode's contents; it does not show whether anything
opens it, and asserting the former had looked like proof of the latter.

Resolved by enabling `kak-ide-keymap-helix-enable` (user's choice): `<space>`
enters the `kak-ide` mode and Kakoune's own `<space>` moves to `<a-space>`.
Since the leader now opens `kak-ide` and not `user`, the everyday commands that
existed only on `,` (`w`, `q`, `c`, `=`, `n`, `p`, `l`, `t`, `z`, close-buffer)
were carried into that mode on the same letters — `n`/`p` and close-buffer also
answer items 1 and 3 of `kakoune_bugs.md`.

`test/keymap.sh` now asserts that *some* leader reaches the IDE bindings, and
that `<a-space>` still performs Kakoune's displaced `<space>`.

## W. Unescaping the dump destroys the key names it is read for

`debug mappings` escapes both columns, so the obvious normalizer —
`sed 's/<space>/ /g'` over the whole line — rewrites the *key* `<space>` into a
literal blank and makes `<space>` and `<a-space>` permanently unmatchable. The
assertion then fails against a binding that is present and correct. `keymap.sh`
unescapes only the command half, leaving the key column as Kakoune printed it.

Related: `<a-space>`'s command *is* the literal key `<space>`, so it is asserted
on its docstring rather than its command text.

---

# Addendum — §10 performance sanity (the last unverified exit criterion)

## X. The grep picker streamed the whole tree into fzf

Plan §10 asks that global search on a repo of realistic size (">= this Helix
repo's own scale, ~5k+ files") return "well under a second". Nothing tested it:
this config's own tree is ~100 files and can never exercise the bar. Measured
against the cargo registry checkout (25,817 files, 5x the plan's bar):

| | startup output | time |
|---|---|---|
| before | 9,470,448 lines / **1.02 GB** | **1.50 s** |
| after  | 2,000 lines / 199 KB | **0.024 s** |

The cause was the idiom `rg ''` — an empty pattern matching every line of every
file, handing the entire tree to fzf and letting fzf do all the matching. That
is fine at 100 files and pathological at 25k, and it is the shape fzf.kak's
examples use.

Fixed by inverting which tool searches: `--disabled` turns fzf's own matching
off and `--bind change:reload:` re-runs `rg` per keystroke instead, so only
matches are ever transferred. Measured per-query cost on the same tree is
0.03-0.13 s. `--max-count=50` caps per-file hits so a single generated or
minified file cannot flood the list, and `head -n 2000` bounds the transfer;
`rg` exits on SIGPIPE, so the cap costs no extra scanning.

Output shape is unchanged (`path:line:text`), so the existing `-filter` and
preview commands apply verbatim — verified by capturing the actual generated
shell command rather than reasoning about the quoting.

## Y. Two ways this measurement could have lied

Both hit while writing `test/perf.sh`, both in the same family as the
`timeout(1)` and `write`-no-op notes above:

- **zsh does not word-split unquoted variables.** `$RG -- 'pat'` with
  `RG="rg --flags..."` returns 0 results in the interactive zsh used to explore,
  and 432 under the `/bin/sh` that actually runs the generated script. An
  ad-hoc shell check can therefore report a failure the real code path does not
  have. The config embeds the command literally, so it was never affected.
- **A perf test that silently skips is worse than none.** `perf.sh` exits
  `SKIP` — never `PASS` — when no >=5000-file repo is available, so a green run
  can not come from an assertion that never executed. Point it elsewhere with
  `KAK_IDE_PERF_REPO`.

The bounded-startup assertion was verified to reject the old implementation
(1.02 GB against a 5 MB ceiling), not merely to accept the new one.

---

# Addendum — Phase 5 (DAP)

Built after the user confirmed priority, which §9 requires. Adapters:
`lldb-dap` 22.1.8 (stdio) for Rust, `vscode-js-debug` 1.117.0 (TCP) for
JS/TS — the latter installed to `~/.local/share/kak-ide/js-debug`, the same
kak-ide-owned prefix Phase 1 used for TypeScript. It is not on npm; it ships as
a GitHub release asset (`js-debug-dap-*.tar.gz`).

Verified end to end through a real Kakoune client, both adapters: set a
breakpoint, run, stop on it, read locals, step out, step over, continue to exit.

## Z. Three deadlocks, all the same shape

The reader thread is the only thread that dispatches responses, so **any
blocking request issued from it waits on itself**. Hit three times before the
root cause was fixed once:

1. `launch` — lldb-dap withholds the launch *response* until it receives
   `configurationDone`, which is only sent from the `initialized` event. Waiting
   for the response blocks the thread that must deliver it.
2. `configurationDone`/`setBreakpoints` in the `initialized` handler.
3. `stackTrace` in the `stopped` handler — the one that matters most, since
   without it there is no stop location and no variables.

Fixed properly by dispatching every event on its own worker thread, so handlers
may block freely; `notify()` remains for the genuine fire-and-forget cases.
Patching each site individually would have left the next one to be found later.

## AA. Failures that produce no error at all

Four bugs where the debugger silently did nothing rather than reporting a fault:

- **Symlinked paths.** macOS `/tmp` is `/private/tmp`, and a debug binary
  records the resolved form. Sending the unresolved path gets
  `verified: false` — accepted, never bound, program runs to completion.
  Every path handed to an adapter is `realpath`'d now.
- **`threadId: 0`.** js-debug numbers threads from 0, and `b.get("threadId") or
  self.thread_id` discards it. `thread_id` stayed `None`, so every step failed
  its guard and was dropped without a request being sent. Falsy-zero.
- **`startDebugging`.** js-debug is a *parent* session: it does not run the
  program, it asks the client to open a child session per target. Refusing the
  reverse request leaves breakpoints at `provisionalBreakpoint` forever. The
  client now opens the child and routes control to it.
- **Socket timeout.** The connect timeout stayed on the socket and applied to
  every `recv`, killing the reader mid-session — a debug session is idle by
  nature while stopped at a breakpoint.

## AB. Kakoune-side traps

- **`echo -markup` treats `{...}` as a face.** `%{...}` around a program name
  makes Kakoune parse `app.js` as a colour: *"unable to parse color: 'app.js'"*.
  Only the leading `{Information}` may be markup. Rust escaped this by luck —
  `dapfix` contains no dot.
- **`line-specs` is a list, not a joined string.** `"2|●|7|●"` is rejected with
  "too many elements in tuple"; each `line|text` must be its own argument.
- **`kak -p` has no client.** Buffer-scoped options (`filetype`) read empty and
  `execute-keys` fails with "no input handler in context". Real use is always
  from a client; `kak-dap-jump-to` now resolves a concrete client rather than
  relying on `-try-client`, which silently falls back to running client-less.
- **AUDIT finding D, again.** `%sh{}` only receives the `kak_*` variables named
  literally in the block, so `kak_buffile`/`kak_session`/`kak_config` had to be
  named or the adapter was chosen from an empty filetype.

## AC. Breakpoints before the session

Setting breakpoints and *then* starting is the normal workflow, but there is no
daemon to receive them yet and the FIFO write was silently dropped. They are now
held in `kak_dap_pending`, painted in the gutter immediately so the user gets
feedback, and replayed once the adapter reports `initialized`.

---

# Addendum — kakoune_bugs.md

## AD. `map global goto <key>` is accepted for keys goto mode cannot dispatch

Item 3 asked for Helix's `gn`/`gp`. They are not reachable, and the way they
fail is worth recording because it defeats the verification method used
everywhere else in this bundle:

    map global goto n ': buffer-next<ret>'   # succeeds, no error
    debug mappings                           # lists `goto n` as bound
    press gn                                 # "key not mapped"

Kakoune's goto mode is implemented in C++ and only dispatches keys it already
knows. `map` records the binding and `debug mappings` faithfully reports what
was recorded — but the goto handler never consults it for a letter that is not
one of its own. Reproduced in a bare `kak -n` with no config, so it is upstream
behaviour rather than a conflict in this config.

Tested: `D`, `i` accept maps (they are real goto keys — which is why the Phase 6
`gD`/`gi` bindings work); `n`, `p`, `q`, `w`, `z`, `Q` are all rejected at press
time despite mapping cleanly.

**Consequence for the method:** `debug mappings` is authoritative for *shadowing*
(finding R) but not for *reachability* in built-in minor modes. A binding needs
pressing to prove it works — the same lesson as finding V, one level deeper.

Buffer navigation therefore went to `]b`/`[b` in the bracket-nav modes this
bundle owns, plus `<space>n`/`<space>p`. `ga` already does Helix's `ga`.

## AE. A `map` before its `declare-user-mode` breaks the whole config

Adding `map global kak-ide B` near the top of `keymap.kak` — above the
`declare-user-mode kak-ide` that appears much further down — fails with
"no such keymap mode: 'kak-ide'", and that error aborts parsing of the entire
`kakrc` chain: every later binding silently disappears. The symptom in
`test/keymap.sh` is indistinguishable from the empty-dump harness bug of
finding T: everything reports "unbound" at once.

Rule: a mode's bindings must live below its `declare-user-mode`. When many
assertions fail simultaneously, check for a parse error in the debug buffer
before trusting the failures.
