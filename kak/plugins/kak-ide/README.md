# kak-ide

An IDE layer for Kakoune, built to `KAKOUNE-PARITY-PLAN.md`.

It sits **on top of** [kakoune-lsp][] and [kak-tree-sitter][] rather than
replacing them, and adds only what neither provides. Nothing here forks or
patches Kakoune's core.

[kakoune-lsp]: https://github.com/kakoune-lsp/kakoune-lsp
[kak-tree-sitter]: https://git.sr.ht/~hadronized/kak-tree-sitter

## Status

**Phase 1 (language plumbing) complete.** Phases 2–6 are not started; see
"Roadmap" below and `AUDIT.md` for how the plan's estimates changed once the
real versions on this machine were checked.

## Install

Already wired into this config. `kakrc` contains, after the `kak-lsp` block:

```kak
source "%val{config}/plugins/kak-ide/rc/kak-ide.kak"
```

Order matters: it must come **after** the `evaluate-commands %sh{ kak-lsp }`
line (it extends `lsp_servers`) and **before** kak-tree-sitter is initialised
(it decides the filetypes tree-sitter keys off).

## What it does today

### Seven languages, end to end

Rust, TypeScript, JavaScript, JSX, TSX, HTML, CSS (+SCSS/LESS) and Lua get
filetype detection, indent width, comment tokens, a tree-sitter grammar with
query set, and a configured language server.

Two things here are not just configuration:

- **`.jsx`/`.tsx` get their own filetypes.** Kakoune maps them to
  `javascript`/`typescript`, but kak-tree-sitter picks its grammar from
  `filetype`, and the `typescript` query set cannot parse JSX. Giving them
  distinct filetypes makes tree-sitter select the JSX-capable queries; the
  pieces Kakoune only ships for javascript/typescript (indent hooks, comment
  tokens, `languageId`, a static-highlighter fallback) are re-supplied.
- **The TypeScript server is chosen, not assumed.** `kak_ide_ts_server`
  defaults to `auto`, which prefers **vtsls** when it is on PATH. vtsls vendors
  its own TypeScript, so it works in a project with no `node_modules`;
  `typescript-language-server` vendors none, refuses to start without one, and
  that failure *panics kak-lsp* and disables LSP for the buffer — so kak-ide
  never hands it a configuration it cannot start from. Either server is checked
  against the project's own TypeScript when the project pins one (`tsserver.path`
  for tsls, `typescript.tsdk` for vtsls), falling back to a copy kak-ide keeps
  under `~/.local/share/kak-ide`. Force one with:

  ```kak
  set-option global kak_ide_ts_server vtsls                       # or
  set-option global kak_ide_ts_server typescript-language-server
  ```

### Formatter / linter detection (plan §6.1)

Resolved once per project root, cached per buffer:

| Project contains | Formatter | Linter |
|---|---|---|
| `biome.json(c)` | Biome (JS/TS/JSX/TSX/JSON/CSS) | Biome (JS/TS/JSX/TSX/JSON) |
| ESLint config | ↓ | ESLint, attached as a second server |
| Prettier config | Prettier | ↓ |
| none of the above | the language server | the language server |

Biome is deliberately **not** used for HTML (it has no HTML support) and not
for CSS *linting* (it lints JS/TS/JSON only) — CSS diagnostics stay with
`vscode-css-language-server`. Project-local `node_modules/.bin` wins over a
global install, so a repo that pins its own Prettier gets that Prettier.

Format-on-save is on by default. Inspect or change it:

```
:kak-ide-tooling-info              show what resolved for this buffer
:kak-ide-status                    root, trust, filetype, formatter, linter
:kak-ide-format-on-save-toggle     turn format-on-save off/on
:kak-ide-modeline-enable           show fmt/lint in the modeline
```

### Workspace trust (plan item 11)

Opening a file from an untrusted directory should not silently launch a
language server: LSP config names an arbitrary binary, and a repo-local
`.eslintrc.js` or `biome.json` is content someone else wrote.

The mechanism is built and **off by default**, because switching it on would
stop LSP working in every existing project until each is trusted. Enable with:

```kak
set-option global kak_ide_trust_enable true
```

Then `:kak-ide-trust` / `:kak-ide-untrust` / `:kak-ide-trust-list`. Trusted
roots persist in `%val{config}/kak-ide-trusted`.

### Project-wide refactoring (plan §7.1, §7.2)

| Key | Action |
|---|---|
| `,R` | rename symbol across the workspace (LSP) |
| `,%` | project-wide find & replace |

**Find & replace** (`,%`, or `:kak-ide-replace <pattern> <replacement>`) stages a
unified diff of every change into a scratch buffer and writes **nothing** until
you run `:kak-ide-replace-apply`. `:kak-ide-replace-abort` discards it.
Discovery is ripgrep `--pcre2` and substitution is perl — both PCRE, so the set
of files previewed is exactly the set that changes. `.gitignore` is respected,
`$1..$9` backreferences work, and the replacement is **never eval'd** (a
replacement string is text, not code — there is a regression test for this).

**⚠️ Rename writes to disk.** kakoune-lsp applies a rename in-memory for the
buffer you are in, but writes every *other* affected file **straight to disk**,
with no confirmation. Measured on a 3-file fixture: 2 of 3 files were silently
rewritten. Plan §7.1 asks for the opposite ("do not silently write to disk"),
and that is **not reachable from the plugin boundary** — pre-opening the files
as buffers does not prevent it (also measured). So `kak-ide-rename`:

- opens every file mentioning the symbol, so they are all in the buffer list
  with in-session undo history;
- shows the resulting `git diff` immediately, so the change is reviewed after
  the fact rather than not at all;
- `:kak-ide-rename-check` warns first if the work tree is already dirty — which
  is exactly when that post-hoc diff stops being attributable.

The escape hatch is `git checkout -- .` from the project root. Prefer renaming
from a clean work tree.

### Pickers (plan §7.4)

Built in Kakscript over `fzf.kak` — **not** a Rust sidecar; see the RESOLVED
decision in `KAKOUNE-PARITY-PLAN.md` §5. fzf is already a fast compiled matcher,
so there was no matching cost to reclaim by writing a daemon.

| Key | Picker | Source |
|---|---|---|
| `,f` / `,F` | files (project / buffer dir) | fzf.kak |
| `,b` | buffers | fzf.kak |
| `,/` | global search | fzf.kak + rg |
| `,g` | **changed files (git)** | new |
| `,j` | **recent locations** | new |
| `,:` | **command palette** | new |
| `,'` | **last picker** | new |
| `,s` / `,S` | symbols (document / workspace) | kakoune-lsp |
| `,x` | diagnostics | kakoune-lsp |
| `,e` | file explorer | kaktree |
| `<space>v` / `<space>h` | **file → open in split** | new (WezTerm panes) |
| `,a` / `,R` | code actions / rename symbol | kakoune-lsp |

Two honest caveats:

- **`,j` is not Kakoune's jumplist.** Kakoune keeps one for `<c-o>`/`<c-i>` but
  exposes no value to read it, so a faithful jumplist picker needs a core patch.
  This is a deduplicated ring of positions recorded on buffer display — what a
  jumplist picker is actually used for — named for what it is.
- **Split-open is WezTerm-native, not tmux.** fzf.kak's own hsplit/vsplit
  wrappers shell out to `tmux-terminal-*` and only work inside tmux. Kakoune has
  no internal splits — a "split" is a second client in a second terminal pane —
  so `kak-ide-picker-files-vsplit` / `-hsplit` (`<space>v` / `<space>h` in the
  Helix map) spawn a Kakoune client on the *same session* in a WezTerm pane.
  Same session means both panes share buffers, registers and the running
  language servers. Falls back to Kakoune's `terminal` elsewhere. No tmux
  needed.

The command palette builds its own index (778 entries here): Kakoune exposes no
way to enumerate commands — no `%val`, no `debug commands`, and this build ships
no doc pages — so the index is scraped from `define-command` across everything
loaded, unioned with a static list of C++ builtins and kakoune-lsp's generated
commands. Rebuild after installing a plugin with `:kak-ide-palette-refresh`.

### Reaching capability that was already installed

Two opt-in modules, enabled in `kakrc`, that bind things which were installed
and unreachable rather than adding anything new:

- `kak-ide-keymap-treesitter-enable` — kak-tree-sitter ships **70 bindings**
  across its own user modes and no way in. Adds `,t` plus Helix-style
  `<a-o>`/`<a-i>`/`<a-n>`/`<a-p>` for parent/child/sibling. Object mode is left
  alone: kak-tree-sitter already maps `<a-i>f/t/a/T` itself.
- `kak-ide-keymap-git-enable` — Kakoune's own `git.kak` has `show-diff`,
  `next-hunk`, `prev-hunk`. Adds `]`/`[` nav modes (`]c` hunks, `]d` diagnostics,
  `]f` functions) and refreshes the diff gutter on open/write, which stock
  `git.kak` never does.

`kak-ide-keymap-helix-enable` puts the full §8 table on `<space>` and is **off**
by default: `<space>` drops all but the main selection in Kakoune, and §8 rule 4
says Kakoune's binding wins a conflict.

## Testing

```
plugins/kak-ide/test/smoke.sh          # config resolution, ~10s
plugins/kak-ide/test/smoke.sh --lsp    # also starts servers, ~90s
```

The fixture is a real multi-file project (the plan requires this — single
files do not exercise root detection or import resolution). Rebuild it with
`test/make-fixture.sh`; override its location with `KAK_IDE_FIXTURE`.

## Options

| Option | Default | Meaning |
|---|---|---|
| `kak_ide_last_picker` | (computed) | picker replayed by `,'` |
| `kak_ide_jump_ring_size` | `60` | recent-locations ring length |
| `kak_ide_ts_server` | `auto` | `auto` (prefers vtsls) / `vtsls` / `typescript-language-server` |
| `kak_ide_root_markers` | `.git .hg … Makefile` | project root markers; VCS root wins |
| `kak_ide_project_root` | (computed) | this buffer's project root |
| `kak_ide_format_on_save` | `true` | format on write when a formatter resolved |
| `kak_ide_formatter` | (computed) | `biome`/`prettier`/`stylua`/`lsp`/`none` |
| `kak_ide_linter` | (computed) | `biome`/`eslint`/`lsp`/`none` |
| `kak_ide_trust_enable` | `false` | gate LSP startup on a trust decision |
| `kak_ide_trust_file` | `%val{config}/kak-ide-trusted` | persisted trusted roots |

## Roadmap

| Phase | Scope | State |
|---|---|---|
| 0 | Audit | done — `AUDIT.md` |
| 1 | Language plumbing, §6.1 tooling, workspace trust | **done** |
| 2 | Multi-file rename, project-wide find/replace | **done** — rename verified across 3 files; find/replace built. See the disk-write warning above |
| 3 | Unified picker core, file explorer, command palette | **done** — goto-file/import resolvers still open |
| 4 | Tree-sitter textobjects/motions, git gutter + hunk nav | **done via keymap modules** — both were already implemented upstream |
| 5 | DAP | out of scope unless requested |
| 6 | Keybinding reconciliation | not started (must come last) |
