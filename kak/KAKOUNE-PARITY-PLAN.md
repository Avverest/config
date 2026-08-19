# Bringing Helix's Feature Set to Kakoune — Implementation Plan

**Audience:** This document is an execution plan for an autonomous coding agent
(Claude Opus 5, run via Claude Code) to implement in one or more Kakoune-related
repositories. It is *not* a patch against this repository (Helix) — Helix is
used here only as the feature/keymap source of truth. All engineering described
below happens in Kakoune's own repo and its plugin ecosystem
(`kak-lsp`, `kak-tree-sitter`, `fzf.kak`, etc.).

**Mandatory requirements from the requester:**
1. Kakoune must gain **project-wide refactoring** (multi-file rename, workspace
   find/replace).
2. Kakoune must gain **file/import navigation** across the project (goto file,
   goto import target, project file/symbol pickers).
3. First-class language support for: **TypeScript, JavaScript (+ React/JSX/TSX),
   HTML, CSS, Rust, Lua**.
4. Keybindings should be brought in line with Helix's default keymap (below),
   reconciled with Kakoune's own long-standing conventions.

---

## 1. How to use this document

Work phase by phase (Section 9). Each phase is scoped to be a self-contained
PR (or small PR series) against a specific upstream repo. Do not attempt all
phases in one session — checkpoint after each phase, run the validation steps
in Section 10, and report status before continuing. Where a decision point is
marked **[DECISION]**, a recommendation is given, but confirm with the user
before committing to the alternative that requires patching Kakoune's C++ core.

---

## 2. Feature inventory: what Helix has

Helix is a Kakoune-lineage modal editor with selection-first editing, built-in
tree-sitter, and a built-in LSP/DAP client. The following is the full feature
surface to bring to Kakoune, grouped by subsystem.

### 2.1 Core editing model
- Modal editing: Normal / Insert / Select(extend) / Command modes, plus minor
  modes (`g` goto, `m` match, `z`/`Z` view, `Ctrl-w` window, `Space` space).
- **Selections are primary, cursors are a side effect** (multiple selections
  by default, not an opt-in mode).
- Selection algebra: split on regex (`S`), select regex matches in selection
  (`s`), merge (`Alt- -`), merge consecutive (`Alt-_`), keep/remove matching
  (`K` / `Alt-K`), align in columns (`&`), trim whitespace (`_`), rotate
  main selection / rotate selection contents, copy selection to next/prev
  line (add cursor above/below), flip anchor/cursor, collapse to cursor.
- Registers (named clipboards) incl. system/primary clipboard registers,
  search register, macro register.
- Macros: record (`Q`) / replay (`q`) to any register.
- Undo tree with timestamped history (`u`/`U`, `Alt-u`/`Alt-U` = earlier/later,
  undo checkpoints in insert mode).
- Multi-line/joined yank, replace-with-yanked, replace selections with
  clipboard.

### 2.2 Movement & search
- Character/word/WORD/sub-word motions (start/end, forward/back).
- `f`/`F`/`t`/`T` find-char motions **not confined to the current line**.
- Line/file/column goto family (`gg`, `ge`, `G`, `g|`, `gh`/`gl`, `gs`).
- Regex incremental search (`/`, `?`, `n`/`N`), search-selection (`*`,
  `Alt-*`), global (workspace) regex search.
- Jumplist with save/forward/backward (`Ctrl-s`, `Ctrl-o`, `Ctrl-i`).
- "Goto word" two-character label jump (`gw`), similar to easymotion/leap.

### 2.3 Text objects, surround, structural motion
- `mi`/`ma` (inside/around) text objects: word, WORD, paragraph, surround
  pairs, closest surround pair, **function, type/class, argument/parameter,
  comment, test, change, (X)HTML element** (the bold ones need tree-sitter
  textobject queries).
- Surround add/replace/delete (`ms`, `mr`, `md`), matching bracket (`mm`).
- Tree-sitter structural selection: expand/shrink selection to parent/child
  node, select next/prev/all sibling(s), select all children, move to
  start/end of parent node.
- Unimpaired-style `[`/`]` navigation: next/prev diagnostic, function, class,
  parameter, comment, test, paragraph, change (git), XML element, plus
  first/last variants.

### 2.4 Editing & shell integration
- Indent/unindent, format selection (LSP), join (with/without space-select),
  switch case (toggle/upper/lower), increment/decrement numbers.
- Comment/uncomment (line, block, auto-detect).
- Shell pipe (`|`), pipe-ignore-output (`Alt-|`), insert-output (`!`),
  append-output (`Alt-!`), filter-by-exit-code (`$`).

### 2.5 Windows, buffers, files
- Splits: hsplit/vsplit, transpose, swap/jump between splits, close/only.
- Buffer list, next/prev buffer, last-accessed/last-modified file.
- `gf` — goto file/URL under selection (with hsplit/vsplit variants).
- File explorer (tree view) rooted at workspace or current buffer dir.

### 2.6 Pickers (fuzzy, `Space` mode)
File picker (workspace-root and cwd variants), buffer picker, jumplist
picker, changed-file picker (git), document/workspace symbol pickers
(LSP-or-syntax fallback), document/workspace diagnostics pickers, global
search (regex, ripgrep-style, results picker), last-picker recall,
command palette (typable commands + bound keys), all sharing one picker UI
(fuzzy filter w/ column-scoped queries, preview pane, open in hsplit/vsplit,
background-open).

### 2.7 LSP integration
Completion (auto + manual `Ctrl-x`), signature help, hover docs, diagnostics
(inline + gutter + pickers), **goto definition/declaration/type-definition/
references/implementation**, **rename symbol (workspace-wide)**, code
actions, format document/selection, inlay hints, workspace commands,
multi-server-per-language with feature-level server selection
(`only-features`/`except-features`), `:lsp-restart`/`:lsp-stop`.

### 2.8 Tree-sitter
Syntax highlighting, injections (embedded languages, e.g. JS in HTML, CSS in
JS template literals), indentation queries, textobject queries, rainbow
bracket queries, locals/scopes, tag queries — all declared per-language via
query files, loaded through `languages.toml`.

### 2.9 DAP (Debug Adapter Protocol)
Launch/restart/terminate, breakpoints (toggle, conditional, log message),
continue/step in/out/next, variables view, thread/stack-frame switching,
exception breakpoints.

### 2.10 Git/VCS
Diff gutter (added/changed/removed markers), goto next/prev/first/last
change, reset hunk at cursor (`:diffget`), changed-file picker.

### 2.11 Config system
- `languages.toml`: per-language file-type detection, comment tokens, indent
  style, associated language servers + per-server JSON config,
  tree-sitter grammar/query sources.
- `config.toml` `[editor]` tree: statusline, cursor shape, file-picker
  ignore rules, file-explorer, buffer-picker, auto-pairs, auto-save, search
  (smart-case etc.), whitespace rendering, indent guides, gutters (line
  numbers/diagnostics/diff/spacer/code-action-hint), soft-wrap, smart-tab,
  inline-diagnostics verbosity, word-completion, workspace-trust (prompt
  before running LSP/config from an untrusted directory).
- Runtime `:set`/`:toggle`/`:get` for any config option; `:config-reload`.
- Themes (TOML, scoped highlight names).

Full default keymap and typable-command tables are reproduced in Appendix A/B
for direct reference — use them as the literal target when wiring Kakoune
key maps in Section 8.

---

## 3. Baseline: what Kakoune already has

Kakoune predates and directly inspired Helix's selection model, so the core
editing experience is *already* close. Audit these before writing new code —
do not reimplement what exists.

| Area | Kakoune native | Notes |
|---|---|---|
| Modal editing, selection-first model, multiple selections | ✅ native | Kakoune invented this; keys mostly already match Helix's origin. |
| Registers, macros, undo tree | ✅ native | `q`/`Q`... verify exact letter parity against Appendix A. |
| Shell pipe/filter (`\|`, `!`, `$`-family) | ✅ native | Compare exact key parity. |
| Regex search, selection splitting/algebra (`s`, `S`, `%`, `x`, `X`, alignment `&`) | ✅ native | Same lineage as Helix; likely near-identical already. |
| Object/textobject selection (word/paragraph/surround) | ✅ native (`<a-i>`/`<a-a>` families) | Tree-sitter-driven objects (function/type/arg/comment/test/xml) are **not** native — see 3.1. |
| Surround add/replace/delete | Plugin: `surround.kak` (or similar) | Needs to be first-class / bundled. |
| Client/server split architecture, multiple clients on one session | ✅ native, no Helix equivalent needed | Kakoune's own strength; keep as-is. |
| Basic LSP client (completion, hover, goto-def/decl/ref/impl, diagnostics, format, code actions, rename) | Plugin: **`kak-lsp`** (Rust daemon) | Mature, but workspace-wide rename across files and workspace symbol search need verification/extension — see Section 7. |
| Tree-sitter highlighting/textobjects/motions | Plugin: **`kak-tree-sitter`** (Rust daemon, by the `kak-tree-sitter` project) | Provides highlighting + some object/motion support already; extend for full textobject query parity (function/class/arg/comment/test) and injections. |
| Fuzzy pickers (file/buffer/grep) | Plugins: `fzf.kak` / `skim`-based configs | No unified picker UI matching Helix's column-scoped filter + preview + hsplit/vsplit open; needs a dedicated picker core (Section 7.4). |
| File explorer | Plugins: `ranger.kak`, `lf.kak`, or similar | Not tree-native to Kakoune; needs a first-party minimal explorer, or standardize on one plugin. |
| Command palette | ❌ none standard | New. |
| Git gutter / VCS | Plugins: `git.kak`, `kakoune-vcs`, or similar | Needs standardizing + parity for hunk navigation/reset + changed-file picker. |
| DAP | ❌ none standard | New; large scope, lowest priority (Section 9, Phase 5). |
| Snippets/tabstops | Plugin ecosystem, inconsistent | LSP snippet support (`goto_next_tabstop`) needs wiring through `kak-lsp`. |
| Workspace trust prompt | ❌ none | New, small — gate LSP/local-config loading behind a per-directory trust prompt. |
| `languages.toml`-equivalent unified language config | ❌ fragmented across `kak-lsp`'s `servers.toml`, `kak-tree-sitter`'s own config, and hand-written `.kak` filetype files | Recommend a single source-of-truth file (Section 6) that generates/feeds all three. |

**[DECISION]** Recommendation: do **not** fork Kakoune's C++ core for most of
this work. Kakoune's core is deliberately minimal and orthogonal — nearly
everything above is implementable as (a) contributions to `kak-lsp`, (b)
contributions to `kak-tree-sitter`, (c) a new first-party Kakscript+small-Rust
plugin bundle for pickers/explorer/git/palette, and (d) `.kak` config/keymap
files. Reserve core C++ patches for cases genuinely impossible at the plugin
boundary (identified case: safely applying a multi-file `WorkspaceEdit`
against buffers that may be open in other clients — see 7.1). Confirm this
boundary with the user before starting any core patch.

---

## 4. Gap analysis summary

| # | Feature | Kakoune status | Action |
|---|---|---|---|
| 1 | Multi-file rename / workspace refactor | Partial in `kak-lsp` (single-buffer edits only, unverified multi-file) | **Build** — Phase 2 |
| 2 | Project-wide find/replace | None unified | **Build** — Phase 2 |
| 3 | Goto file / import resolution | `gf`-equivalent missing; no import-aware resolver | **Build** — Phase 3 |
| 4 | Unified fuzzy picker (file/buffer/symbol/diagnostics/search/palette) | Fragmented plugins | **Build** — Phase 3 |
| 5 | File explorer | 3rd-party only | **Standardize/build** — Phase 3 |
| 6 | Tree-sitter textobjects/motions (function/class/arg/comment/test/xml, injections) | Partial via `kak-tree-sitter` | **Extend** — Phase 4 |
| 7 | Git gutter + changed-file picker + hunk nav/reset | 3rd-party, inconsistent | **Standardize/build** — Phase 4 |
| 8 | Language servers wired for the 7 target languages | Ad hoc per user config | **Build** — Phase 1 |
| 8b | Prettier/ESLint/Biome format + lint for React/TS/JS (+CSS) | None wired by default | **Build** — Phase 1 (§6.1) |
| 9 | Inlay hints, signature help, snippets/tabstops | Partial/missing in `kak-lsp` | **Extend** — Phase 2 |
| 10 | DAP | None | **Build (optional/stretch)** — Phase 5 |
| 11 | Workspace trust prompt | None | **Build (small)** — Phase 1 |
| 12 | Unified language-config source of truth | None | **Build** — Phase 1 |
| 13 | Keybinding parity with Helix defaults | Partially overlapping by heritage | **Reconcile** — Phase 6 (do last, after features exist to bind) |

---

## 5. Architecture

Ship as a coordinated bundle, not a Kakoune core fork:

```
kakoune                (upstream, unforked if possible)
├─ kak-lsp              (fork/extend: multi-file WorkspaceEdit apply,
│                         workspace symbols, inlay hints, signature help,
│                         snippets, workspace/executeCommand passthrough)
├─ kak-tree-sitter       (fork/extend: full textobject query set,
│                         injections, structural selection commands)
└─ kak-ide               (NEW plugin suite, Kakscript + a small Rust
                           helper daemon where needed, providing:
                           - unified picker core (file/buffer/symbol/
                             diagnostics/global-search/command-palette/
                             jumplist/changed-file)
                           - file explorer
                           - git gutter + hunk nav/reset + changed-files
                           - project-wide find/replace UI
                           - goto-file / import resolver per language
                           - workspace-trust prompt
                           - `languages.toml`-equivalent config loader that
                             feeds kak-lsp's servers.toml and
                             kak-tree-sitter's language config from one file)
```

Distribute via a bootstrap script (`kak-ide-install.sh`) that installs/pins
compatible versions of `kak-lsp`, `kak-tree-sitter`, and `kak-ide`, and drops
a single `kakrc` snippet (`source kak-ide/rc/kak-ide.kak`) the user adds to
their config. Do not require patching a user's existing `kakrc` beyond that
one `source` line.

> ### ✅ RESOLVED 2026-08-19 — build on `fzf.kak`, no Rust sidecar
>
> The picker core is implemented in Kakscript on top of `fzf.kak`, not as a
> Rust sidecar daemon. Rationale:
>
> - The performance argument does not apply here. The sidecar case rests on
>   fuzzy-matching cost in Kakscript, but `fzf.kak` shells out to **fzf**, which
>   is already a fast compiled matcher. That cost is not being paid today.
> - What `fzf.kak` actually lacks is *uniformity* — column-scoped filters,
>   preview toggle, last-picker recall, one UI for non-file data (symbols,
>   diagnostics, jumplist). Those are UI concerns, reachable in Kakscript.
> - A third daemon means a compiled binary to build, version and keep in step
>   with `kak-lsp` and `kak-tree-sitter`. `fzf.kak` is already installed and
>   `fd`/`rg` are already on PATH.
> - `fzf.kak`'s generic `fzf` command (`-items-cmd`/`-kak-cmd`/`-filter`/
>   `-fzf-args`/`-preview-cmd`) is a sufficient primitive for every picker in
>   Section 7.4.
>
> Revisit only if a real monorepo measurably drags. The sidecar remains the
> right call for `kak-lsp` and `kak-tree-sitter`, which hold unavoidable
> resident state (LSP sessions, parsed syntax trees); a picker holds none.

**[DECISION]** Building `kak-ide` in Rust (as a sidecar daemon that talks to
Kakoune the same way `kak-lsp`/`kak-tree-sitter` do — via `kak -p`/FIFO
pipes and generated `.kak` commands) is recommended over pure Kakscript for
the picker core and the multi-file refactor engine, for performance on large
monorepos and to reuse `ignore`/`grep`/`serde` crates. Pure Kakscript is fine
for glue, keymaps, and the file explorer UI.

---

## 6. Language support matrix (target: TS, JS, JSX/TSX, HTML, CSS, Rust, Lua)

Transcribed from this repo's `languages.toml` — use as the literal config
values when writing `kak-ide`'s unified language config and generating
`kak-lsp`'s `servers.toml` / filetype detection in Kakoune.

| Language | File types | Language server(s) | Comment token(s) | Indent | Notes |
|---|---|---|---|---|---|
| Rust | `rs` | `rust-analyzer` | `//`, `///`, `//!` (block: `/* */`) | 4 spaces | inlay hints: closure return types, lifetime elision (skip trivial), discriminant hints; `files.watcher = "server"`. |
| JavaScript | `js`, `mjs`, `cjs`, `es6`, plus misc (`.node_repl_history`, `jakefile`) | `typescript-language-server` + auto-detected Biome or ESLint (lint) + Prettier or Biome (format) — see §6.1 | `//` (block: `/* */`) | 2 spaces | |
| JSX (React) | `jsx` | same as JavaScript, §6.1 | `//` (block: `/* */`) | 2 spaces | Same server as JS; tree-sitter grammar must support JSX syntax + XML-element textobject/motions (`x`/`]x`/`[x`). |
| TypeScript | `ts`, `mts`, `cts` | same as JavaScript, §6.1 | `//` (block: `/* */`) | 2 spaces | |
| TSX (React) | `tsx` | same as JavaScript, §6.1 | `//` (block: `/* */`) | 2 spaces | Same as JSX note. |
| CSS | `css` | `vscode-css-language-server`; format via Prettier/Biome if configured, else `provideFormatter = true`, `css.validate.enable = true` — see §6.1 | block: `/* */` | 2 spaces | |
| (SCSS/LESS, bundled for free with the CSS server) | `scss`, `less` | `vscode-css-language-server` | block: `/* */` | 2 spaces | Include since they share the server — near-zero extra cost. |
| HTML | `html`, `htm`, `xhtml`, `shtml`, plus templating variants | `vscode-html-language-server` (chain `superhtml` for stricter diagnostics) | block: `<!-- -->` | 2 spaces | |
| Lua | `lua`, `rockspec` | `lua-language-server` | `--`, `---` (block: `--[[ --]]`) | 2 spaces | inlay hints: array index, set-type, param name/type, await hints all enabled. |

Exact language-server launch commands (from this repo's `languages.toml`,
transcribe verbatim into `kak-lsp`'s `servers.toml`):

```toml
[language-server.rust-analyzer]
command = "rust-analyzer"
# config: inlayHints.bindingModeHints.enable=false,
#         inlayHints.closingBraceHints.minLines=10,
#         inlayHints.closureReturnTypeHints.enable="with_block",
#         inlayHints.discriminantHints.enable="fieldless",
#         inlayHints.lifetimeElisionHints.enable="skip_trivial",
#         files.watcher="server"

[language-server.typescript-language-server]
command = "typescript-language-server"
args = ["--stdio"]
# config.hostInfo = "kak-ide"
# config.typescript.inlayHints / config.javascript.inlayHints:
#   includeInlayEnumMemberValueHints=true
#   includeInlayFunctionLikeReturnTypeHints=true
#   includeInlayFunctionParameterTypeHints=true
#   includeInlayParameterNameHints="all"
#   includeInlayParameterNameHintsWhenArgumentMatchesName=true
#   includeInlayPropertyDeclarationTypeHints=true
#   includeInlayVariableTypeHints=true

[language-server.vscode-eslint-language-server]
command = "vscode-eslint-language-server"
args = ["--stdio"]
# config: validate="on", run="onType",
#         codeAction.disableRuleComment.enable=true,
#         codeAction.showDocumentation.enable=true

[language-server.vscode-css-language-server]
command = "vscode-css-language-server"
args = ["--stdio"]
# config: provideFormatter=true, css.validate.enable=true

[language-server.vscode-html-language-server]
command = "vscode-html-language-server"
args = ["--stdio"]
# config: provideFormatter=true

[language-server.lua-language-server]
command = "lua-language-server"
# config.Lua.hint: enable=true, arrayIndex="Enable", setType=true,
#                  paramName="All", paramType=true, await=true

[language-server.vscode-eslint-language-server]
command = "vscode-eslint-language-server"
args = ["--stdio"]
# config: validate="on", run="onType",
#         codeAction.disableRuleComment.enable=true,
#         codeAction.showDocumentation.enable=true

[language-server.biome-lsp-proxy]
command = "biome"
args = ["lsp-proxy"]
```

### 6.1 Formatting & linting tooling for React/TS/JS (Prettier, ESLint, Biome)

Helix's own default `languages.toml` deliberately does **not** wire Prettier,
ESLint, or Biome into JS/JSX/TS/TSX/CSS out of the box — `typescript-
language-server`'s built-in formatter is used unless a user opts in. Since
the requester explicitly wants React/TS/JS projects to get proper
format-on-save and lint diagnostics, `kak-ide` should opt in by default for
these languages (still user-overridable), rather than leaving it to manual
per-project config like upstream Helix does. Add this to Phase 1/2.

**Per-project tool detection** (`kak-ide` config loader, runs once per
workspace root on first buffer open, cached):
1. If `biome.json` or `biome.jsonc` exists at the project root → use
   **Biome** for both formatting and linting (it replaces both Prettier and
   ESLint for JS/TS/JSX/TSX/JSON in one fast Rust binary). Attach
   `biome-lsp-proxy` as an additional `language-servers` entry (after
   `typescript-language-server`, so type-aware features still come from
   `tsserver` while formatting/lint diagnostics/code actions come from
   Biome) — `only-features`/`except-features` should scope Biome to
   `format`/`diagnostics`/`code-action` and leave hover/goto/rename/
   completion to `typescript-language-server`.
2. Else if `.eslintrc*`, `eslint.config.*`, or an `eslintConfig` field in
   `package.json` exists → attach `vscode-eslint-language-server` as an
   additional `language-servers` entry, scoped (`only-features`) to
   `diagnostics`/`code-action`, so ESLint findings and quick-fixes
   (`disableRuleComment`, `showDocumentation`) appear alongside
   TypeScript's own diagnostics.
3. Formatting precedence, independent of the lint choice above: if Biome is
   in use, format with Biome; else if `.prettierrc*`, `prettier.config.*`,
   or a `prettier` field in `package.json` is present, set the language's
   `formatter` to an external command
   (`{ command = "prettier", args = ["--stdin-filepath", "%val{buffile}"] }`
   equivalent — resolve to a local `node_modules/.bin/prettier` first, then
   a global install) instead of relying on `typescript-language-server`'s
   formatter; else fall back to the LSP's built-in formatting.
4. Apply the same precedence to CSS (Prettier or Biome-adjacent formatters
   handle CSS; ESLint/Biome linting is JS/TS/JSON-only — CSS diagnostics
   still come from `vscode-css-language-server`). HTML formatting stays on
   `vscode-html-language-server`/Prettier; Biome does not cover HTML.
5. Expose `auto-format` (format-on-save) as a per-project toggle mirroring
   Helix's `[[language]] auto-format = true`, defaulting **on** for these
   languages once a formatter is resolved, since "format on save" is the
   expected baseline experience for React/TS/JS teams.
6. Surface the resolved chain in the statusline/`:lsp-restart`-equivalent
   status so users can see at a glance whether Biome, ESLint+Prettier, or
   bare-LSP formatting is active for the current buffer — avoids silent
   surprises when a project has conflicting configs.

This detection logic is the same shape as Section 7.3's import resolvers —
implement it in the same `kak-ide` config-loader module rather than as a
separate subsystem.

Tree-sitter: use the same grammar sources Helix uses for these 7 languages
(`tree-sitter-rust`, `tree-sitter-javascript`, `tree-sitter-typescript`
(covers `ts`/`tsx`), `tree-sitter-html`, `tree-sitter-css`, `tree-sitter-lua`)
and port their **textobject / indent / injection query files** (`.scm`) —
these are the pieces `kak-tree-sitter` needs to reach Helix-level structural
editing (function/class/argument/comment/test text objects, JS-in-HTML and
CSS-in-JS injections). Helix's own query files under `runtime/queries/<lang>/`
in this repo are a directly reusable reference/starting point (check license
compatibility — most are MIT, same as Kakoune's ecosystem).

---

## 7. Required capabilities in detail

### 7.1 Project-wide (multi-file) rename / refactor

Engine: `kak-lsp`, extended.

1. Send `textDocument/rename` (or `textDocument/prepareRename` first, if the
   server supports it, to validate the position and get a placeholder).
2. The response is a `WorkspaceEdit` — may touch buffers not currently open
   in any Kakoune client, and files not yet touched this session.
3. New `kak-lsp` responsibility — **apply a `WorkspaceEdit` atomically**:
   - For each file in the edit: open it as a hidden/background Kakoune
     buffer if not already open (`edit -existing` semantics), apply the
     `TextEdit[]` in reverse-offset order (to keep offsets valid), and mark
     the buffer modified.
   - Do **not** silently write to disk — leave modified buffers open and
     surface a summary (files changed, hunk counts) in a review picker
     (reuse the Section 7.4 picker core) so the user can inspect each file's
     diff before a bulk `:write-all`/`wqa`. This mirrors Helix/VSCode
     rename UX and avoids surprise disk writes.
   - If a targeted buffer is open in another client concurrently, coordinate
     through Kakoune's normal buffer-modification path so both clients see
     the update — this is the one spot most likely to need a **small core
     patch** if `kak-lsp`'s existing edit-application command doesn't already
     handle cross-buffer, cross-client updates safely. Investigate
     `kak-lsp`'s current single-file edit path first; extend rather than
     patch core if at all possible.
4. Bind to `rename_symbol` equivalent (see Section 8) → prompts for the new
   name (pre-filled with the placeholder/current symbol), then runs the
   above.

### 7.2 Project-wide find & replace

Engine: `kak-ide` (new), using `ripgrep` for search and `kak-lsp`
`workspace/references` for symbol-scoped replace.

- **Text-based**: `ripgrep --json` search across the workspace root →
  results picker (path, line, column, preview) identical in shape to
  Helix's global-search picker, including column-scoped filtering
  (`%path`, negation with `!`). Selecting a result jumps to it; a
  "replace all" action in the picker runs a regex substitution across every
  matched file, previews a diff, and requires confirmation before writing.
- **Symbol-based**: `textDocument/references` (or `workspace/symbol` +
  references) to scope a replace to actual usages of a symbol rather than
  textual matches — use this as the backing for rename when available, and
  offer it as an explicit "replace all references" action distinct from
  plain-text global replace.
- Respect `.gitignore`/`.ignore` (ripgrep default) plus a configurable
  ignore list mirroring Helix's `[editor.file-picker]` options.

### 7.3 Goto file / import navigation

Engine: `kak-ide` (new), per-language resolver modules, LSP fallback.

- Base primitive: `gf`-equivalent — take the selection (or the path-like
  token under the cursor if selection is empty) and resolve+open it, with
  hsplit/vsplit variants (mirrors Helix's `goto_file` /
  `goto_file_hsplit` / `goto_file_vsplit`).
- Per-language import resolvers (small, mostly regex + filesystem probing,
  invoked when the cursor is on an import/require/use statement):
  - **TS/JS/JSX/TSX**: resolve relative (`./`, `../`) and bare-specifier
    imports; honor `tsconfig.json`/`jsconfig.json` `paths`/`baseUrl`;
    try extensions in order (`.ts`, `.tsx`, `.js`, `.jsx`, `index.*`).
  - **Rust**: resolve `mod x;`/`use crate::...`/`use self::...` to the
    corresponding file under the module tree (`x.rs` or `x/mod.rs`); for
    external crate paths, fall back to LSP goto-definition (rust-analyzer
    already resolves into `~/.cargo/registry` sources).
  - **Lua**: resolve `require("a.b.c")` against configured `package.path`
    equivalents / project root, trying `a/b/c.lua` and `a/b/c/init.lua`.
  - **HTML**: resolve `<script src=...>`, `<link href=...>`,
    `<img src=...>` relative to the file or a configured web-root.
  - **CSS**: resolve `@import` and `url(...)` similarly.
  - Where a language server already resolves this better (e.g.
    rust-analyzer, typescript-language-server both resolve imports via
    goto-definition on the import specifier itself), prefer LSP
    goto-definition and treat the regex resolvers as the *fallback* for
    files/positions with no active server.
- All of the above feed into the same picker core as everything else so
  ambiguous resolutions (e.g. multiple matching extensions) show a
  disambiguation list instead of guessing silently.

### 7.4 Unified picker core

One picker UI (in `kak-ide`) backing: file picker (root/cwd variants),
buffer picker, jumplist picker, changed-file picker, document/workspace
symbol pickers, document/workspace diagnostics pickers, global search,
command palette, "last picker" recall, and the rename/replace review UI from
7.1/7.2. Feature parity target (from Helix's `pickers.md`/keymap):

- Fuzzy filter (fzf-syntax) by default; regex mode for the global-search and
  replace flows.
- Column-scoped filtering with `%column` prefixes (e.g. `%path`).
- Register insertion into the filter query (`Ctrl-r` + register char).
- Preview pane, toggle with a key.
- Open selected in-place / hsplit / vsplit / "open in background without
  closing picker".
- `Escape`/`Ctrl-c` to close, standard nav keys (arrows/`Tab`/`Ctrl-n`/
  `Ctrl-p`/`PageUp`/`PageDown`/`Home`/`End`/`Enter`).

---

## 8. Keybinding plan

Do this **last** (Phase 6), after the underlying commands exist — binding a
key to a nonexistent command is wasted work.

Process:
1. Dump Kakoune's actual current default keymap (`kak -e 'debug options'`
   won't show this — instead diff against Kakoune's `src/normal.cc` /
   `rc/*.kak` default `map`/`hook` definitions in the target Kakoune
   version) to get ground truth, since defaults can drift from memory.
2. Where a Helix default key already matches Kakoune's existing default for
   the *same* action (expected for most base motion/selection keys, since
   Helix copied Kakoune here), leave it alone.
3. Where Kakoune has no equivalent action yet (all of Section 7 plus most of
   `Space`-mode/`g`-mode/`Ctrl-w`-mode in the table below), add it as a new
   user-mode binding, preferring Kakoune's existing minor-mode conventions
   (`g` is already Kakoune's goto mode; extend it rather than replacing it).
   Use `declare-user-mode`/`enter-user-mode` for anything net new (mirrors
   how Helix's `Space`/`g`/`m`/`z`/`Ctrl-w` are themselves minor modes).
4. Where a key genuinely conflicts (same key, different long-standing
   Kakoune meaning vs. Helix meaning), **default to preserving Kakoune's
   existing binding** and place the Helix-equivalent action on a secondary
   binding — this bundle should feel like "Kakoune, IDE-ified," not "Helix
   wearing a Kakoune costume." Flag conflicts explicitly in the PR
   description for user review rather than silently picking a winner.
5. Ship the full set as one togglable keymap module
   (`source kak-ide/rc/keymap-helix-parity.kak`) so users who prefer
   Kakoune's stock bindings for the newly-added commands aren't forced onto
   this scheme.

The full Helix default keymap to use as the target reference is reproduced
in **Appendix A** (normal/insert/select/picker/prompt modes) and
**Appendix B** (every command with every bound key, generated from source).
Priority subset to wire first (these back the mandatory capabilities):

| Action | Helix default | Suggested Kakoune-side binding |
|---|---|---|
| Rename symbol (workspace) | `Space r` | `<space>r` (new IDE user-mode leader) |
| Code action | `Space a` | `<space>a` |
| Goto definition/declaration/type/refs/impl | `gd`/`gD`/`gy`/`gr`/`gi` | extend Kakoune's existing `g` goto mode with `d`/`D`/`y`/`r`/`i` |
| Goto file (`gf`) + import resolution | `gf` | `gf` under `g` mode |
| File picker (root / cwd) | `Space f` / `Space F` | `<space>f` / `<space>F` |
| File explorer | `Space e` / `Space .` | `<space>e` / `<space>.` |
| Buffer picker | `Space b` | `<space>b` |
| Changed-file picker | `Space g` | `<space>g` |
| Document/workspace symbol picker | `Space s` / `Space S` | `<space>s` / `<space>S` |
| Document/workspace diagnostics picker | `Space d` / `Space D` | `<space>d` / `<space>D` |
| Global search | `Space /` | `<space>/` |
| Command palette | `Space ?` | `<space>?` |
| Jumplist picker | `Space j` | `<space>j` |
| Last picker | `Space '` | `<space>'` |
| Diagnostics nav | `]d`/`[d`, `]D`/`[D` | same, under existing bracket-nav convention if present, else add |
| TS structural selection (expand/shrink/siblings) | `Alt-o`/`Alt-i`/`Alt-p`/`Alt-n`/`Alt-a`/`Alt-I` | keep same `Alt-` keys unless conflicting |
| TS textobjects (function/class/arg/comment/test/xml) | `mi`/`ma` + `f`/`t`/`a`/`c`/`T`/`x` | extend Kakoune's existing object-select prefix keys with the same letters |
| Unimpaired TS nav (`]f`/`[f` etc.) | as in Appendix A | same, add if missing |

---

## 9. Phased roadmap

| Phase | Scope | Primary repo(s) | Exit criteria |
|---|---|---|---|
| **0. Audit** | Confirm exact current Kakoune default keymap, current `kak-lsp`/`kak-tree-sitter` capabilities and versions, license check on reused Helix query files. | n/a (research) | Written gap-audit note replacing assumptions in Section 3 with verified facts. |
| **1. Language plumbing** | Wire the 7 target languages end-to-end (file-type detection, servers, indent/comments, tree-sitter grammars+queries); unified language-config source of truth; workspace-trust prompt; Prettier/ESLint/Biome auto-detection and format-on-save for React/TS/JS/CSS (§6.1). | `kakoune` config, `kak-lsp`, `kak-tree-sitter`, `kak-ide` | Opening a `.rs`/`.ts`/`.tsx`/`.jsx`/`.js`/`.html`/`.css`/`.lua` file gets correct highlighting, indent, comments, and a running, correctly-configured LSP with completion/hover/diagnostics; a TS/JS/React project with a Prettier or Biome config formats on save and shows ESLint/Biome lint diagnostics inline. |
| **2. IDE core (LSP-driven)** | Goto-def/decl/type/refs/impl, code actions, format, inlay hints, signature help, snippets/tabstops; **multi-file rename** (7.1); **project-wide find/replace** (7.2). | `kak-lsp`, `kak-ide` | Renaming a symbol used across ≥3 files updates all of them correctly with a reviewable diff before write; global search+replace works across the workspace respecting ignore rules. |
| **3. Navigation & pickers** | Unified picker core (7.4); file explorer; goto-file/import resolvers (7.3) for all 7 languages; command palette. | `kak-ide` | Every picker in the Section 8 table works with parity to its Helix description in `pickers.md`; import-aware `gf` resolves correctly in a real multi-file project per language. |
| **4. Structural editing & VCS** | Full tree-sitter textobject/motion parity (function/class/arg/comment/test/xml + unimpaired nav); injections (JS-in-HTML, CSS-in-JS); git gutter + hunk nav/reset + changed-file picker. | `kak-tree-sitter`, `kak-ide` | Text object and `]x`/`[x`-style nav match Helix's `textobjects.md`/keymap for all 7 languages that have tree-sitter query support; git gutter shows live diff state with working nav/reset. |
| **5. DAP (optional/stretch)** | Debug adapter client: breakpoints, step control, variables, threads/frames, exception breakpoints. | new `kak-dap` | Only start if Phases 1–4 are complete and the user confirms priority — largest, least-requested piece. |
| **6. Keybinding reconciliation** | Apply Section 8 process across everything built in Phases 1–5. | `kak-ide` (keymap module) | Full keymap module ships, conflicts documented, togglable/optional. |

---

## 10. Validation

Per phase, minimum bar before moving on:
- **Smoke test in all 7 languages**: for each of Rust/TS/JS/JSX/TSX/HTML/CSS,
  open a small real-world-shaped multi-file sample project (not a single
  file) and exercise every command claimed done in that phase.
- **Multi-file rename regression test**: a fixture project (e.g. a TS
  function imported and called from 3+ files) with an automated check that
  after rename, `grep -r` for the old name returns nothing and the new name
  appears in the expected N locations.
- **Global search/replace regression test**: fixture with matches across
  multiple files and at least one file that should be excluded via
  `.gitignore`, verifying it's skipped.
- **Import resolution regression tests** per language: relative imports,
  aliased/path-mapped imports (TS), module-tree imports (Rust `mod`),
  `require` (Lua), asset refs (HTML/CSS).
- **Performance sanity**: global search and workspace symbol lookup on a
  repo of realistic size (≥ this Helix repo's own scale, ~5k+ files) should
  return in well under a second for search, a few seconds worst case for a
  cold LSP workspace index.
- No regression in Kakoune's existing default keybindings outside the ones
  explicitly reassigned per Section 8's conflict-resolution log.

---

## Appendix A — Helix default keymap (verbatim reference)

Normal mode, minor modes (goto/match/view/window/space), insert mode,
select mode, picker, and prompt keymaps — reproduced from
`book/src/keymap.md` in this repository. Use this as the literal target
mapping described in Section 8. (See that file directly for the always-
up-to-date version; this snapshot is dated to this repo's HEAD at
`079a789e8`.)

> Full tables omitted here for brevity of this appendix pointer — pull the
> live content from `book/src/keymap.md` (511 lines) in this repository when
> implementing; it was already fully reviewed while compiling Sections 2 and
> 8 above and contains: Movement, Changes (+ Shell), Selection manipulation,
> Search, Minor modes (View/Goto/Match/Window/Space, incl. Popup/Completion/
> Signature-help sub-tables and Unimpaired), Insert mode, Select/extend mode,
> Picker, and Prompt keymaps.

## Appendix B — Helix static & typable commands (verbatim reference)

Every built-in command name, description, and every bound key across normal/
select/insert modes is in `book/src/generated/static-cmd.md` (315 rows); every
`:`-command (typable command) with its aliases is in
`book/src/generated/typable-cmd.md` (103 rows). Both were reviewed in full
while compiling this plan — pull them directly from this repository when
implementing to avoid transcription drift.

## Appendix C — Language config source

`languages.toml` in this repository (5657 lines) is the source of truth
used to compile Section 6; the relevant `[[language]]` and
`[language-server.*]` blocks for `rust`, `javascript`, `jsx`, `typescript`,
`tsx`, `css`/`scss`/`less`, `html`, and `lua` were extracted verbatim above.
