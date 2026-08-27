# kak-ide

A small IDE layer for Kakoune, local to this config.

It sits **on top of** [kakoune-lsp][] and [kak-tree-sitter][] rather than
replacing them, and adds only what neither provides: project-root detection,
formatter/linter resolution, multiplexer-backed splits, a file browser and a
surround mode. Nothing here forks or patches Kakoune's core.

[kakoune-lsp]: https://github.com/kakoune-lsp/kakoune-lsp
[kak-tree-sitter]: https://git.sr.ht/~hadronized/kak-tree-sitter

## Install

Already wired into this config. `kakrc` contains, after the `kak-lsp` block:

```kak
source "%val{config}/plugins/kak-ide/rc/kak-ide.kak"
```

Order matters: it must come **after** the `evaluate-commands %sh{ kak-lsp }`
line (it extends `lsp_servers`) and **before** kak-tree-sitter is initialised
(it decides the filetypes tree-sitter keys its grammar choice off).

`rc/kak-ide.kak` sources its siblings in a fixed order:

    project → mux → languages → tooling → splits → files → surround → keymap

## Modules

### project.kak — project root

A VCS root always wins; otherwise the directory tree is walked upward looking
for `kak_ide_root_markers`. The shell logic lives in the `kak_ide_root_sh`
option and is `eval`'d by consumers rather than duplicated.

    kak-ide-project-root      echo the current buffer's root
    kak-ide-detect-root       recompute it (runs on WinCreate)

### mux.kak — multiplexer abstraction

Every pane/window/focus operation goes through this. Two backends, chosen
**per client at call time**: wezterm (when the client's env has
`WEZTERM_PANE`) or tmux. The pane id is always read from `kak_client_env_*`,
never the server's own environment — one session can have clients in several
panes.

    kak-ide-mux-status        report which backend this client drives

### languages.kak — filetypes and servers

Gives `.jsx`/`.tsx` their own filetypes. Kakoune folds them into
javascript/typescript, but tree-sitter picks its grammar from `filetype` and
the typescript queries cannot parse JSX. The indent hooks, comment tokens and
`lsp_language_id` that Kakoune ships only for the base filetypes are then
re-supplied.

### tooling.kak — formatter / linter

Resolved per project root and cached per buffer: biome (when a `biome.json`
is present) → eslint/prettier → LSP. Format-on-save defaults on.

    kak-ide-format                   format the buffer
    kak-ide-format-on-save-toggle    turn format-on-save on or off
    kak-ide-tooling-info             show what resolved for this buffer

### splits.kak — splits as panes

A "split" is a second Kakoune *client* of the same session
(`kak -c $kak_session`) in a multiplexer pane, so panes share buffers,
registers and language servers. Kakoune has no internal splits.

Bound under `,s`:

    v / s / t     split right / below / new window-tab
    h j k l       move focus
    z             zoom this pane
    q / o         close this pane / close all others

### files.kak — file browser

yazi in a zoomed pane. wezterm cannot hand back a pane's stdout, so the
selection travels via `--chooser-file` and a background poll feeds `edit`
commands back with `kak -p "$kak_session"`. Same shape fzf.kak uses.

    kak-ide-files

### surround.kak

A keymap shim over the vendored [h-youhei/kakoune-surround][surr] plugin, which
provides the verbs themselves. Delimiters are read as the next keypress: the
named aliases (`b`/`r`/`B`/`a`/`q`/`Q`/`g`) map to bracket and quote pairs, and
any other character surrounds with itself. Bound under `,m`:

    a <c>         wrap selection in <c>
    d <c>         delete the surrounding <c>
    r <c> <d>     replace <c> with <d>
    s <c>         select the surrounding pair
    t / T         wrap in / remove an HTML tag
    C / S         change / select the surrounding HTML tag

[surr]: https://github.com/h-youhei/kakoune-surround

### keymap.kak

Opt-in binding groups, called from `kakrc`:

    kak-ide-keymap-treesitter-enable
    kak-ide-keymap-git-enable
    kak-ide-keymap-surround-enable

Git hunk and diagnostic navigation hang off `,)` / `,(`.

Git verbs hang off `,g`, wrapping Kakoune's own `git.kak`:

| Key | Does |
| --- | --- |
| `,g b` | toggle blame annotations (`git blame` is itself the toggle) |
| `,g B` | jump to the commit that last touched the line under the cursor |
| `,g l` | `git log` |
| `,g L` | `git log -L` for the selected line range |
| `,g f` | fuzzy-pick a file with uncommitted changes (also `,z c`) |
| `,g d` | `git diff` |
| `,g s` | `git status` |
| `,g h` / `,g H` | show / hide the hunk gutter |

`,g f` runs `fzf-git-changed`, defined in `kakrc` alongside the other project
pickers. It lists `git status` rather than `git ls-tree` — the plugin's own
`fzf-vcs`/`fzf-git` lists every *tracked* file, which is what `,f` already
does. Renames show the new name, deletions are omitted (nothing to open), and
the preview shows the file's diff against `HEAD`, falling back to its contents
for untracked files.

Blame annotations are filled in asynchronously (`git blame --incremental`
feeds them back through `kak -p`), so they land a moment after the keypress
rather than instantly. With blame on, `<ret>` is mapped to `git blame-jump`.

## Commands

    kak-ide-status                   what kak-ide resolved for this buffer
    kak-ide-modeline-enable          show formatter/linter in the modeline
    kak-ide-close-buffer             close, asking if modified
    kak-ide-git-log-line             git log -L for the selected line range

## Options

| Option | Default | Meaning |
|---|---|---|
| `kak_ide_root_markers` | `.git .hg … Makefile` | project root markers; VCS root wins |
| `kak_ide_project_root` | (computed) | this buffer's project root |
| `kak_ide_ts_server` | `auto` | `auto` (prefers vtsls) / `vtsls` / `typescript-language-server` |
| `kak_ide_format_on_save` | `true` | format on write when a formatter resolved |
| `kak_ide_formatter` | (computed) | `biome` / `prettier` / `lsp` / `none` |
| `kak_ide_linter` | (computed) | `biome` / `eslint` / `lsp` / `none` |

## Tests

There is no runner; each is a standalone `sh` script under `test/`. They drive
a real headless Kakoune (`kak -ui json -e …`) and assert on what it resolved.

    cd test
    ./make-fixture.sh     # build /tmp/kakide-fixture (required by smoke)
    ./smoke.sh            # filetype/lang/indent/formatter resolution, ~15s
    ./smoke.sh --lsp      # also start servers, wait for diagnostics, ~90s
    ./keymap.sh           # binding assertions vs `debug mappings`, ~2s
    ./perf.sh             # search latency, ~1s

Override the fixture path with `KAK_IDE_FIXTURE`, the perf repo with
`KAK_IDE_PERF_REPO`. `perf.sh` reports **SKIP**, never PASS, when no
sufficiently large repo is available, so a green run cannot come from an
assertion that never ran.

`keymap.sh` exists because `kakrc`'s own `map` calls run last and silently
overwrite anything kak-ide bound to the same key — Kakoune reports no error
for a duplicate `map`, and bindings have shipped unreachable that way. It
asserts against `debug mappings` (what Kakoune actually resolved), not source.
