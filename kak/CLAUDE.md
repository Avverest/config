# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Super strict rules
- NO write tests
- NO do tests or siumations, i test all after work will done
- NO write comments

## What this is

A personal Kakoune configuration (`~/.config/kak`), not an application. There is
no build step and nothing to install — Kakoune sources `kakrc` at startup. The
git root is the parent directory `~/.config`, which also holds unrelated nvim,
helix and wezterm configs; scope git commands to `kak/` when committing here.

Everything is POSIX `sh` embedded in Kakscript (`%sh{ … }` blocks). Target is
macOS with Kakoune 2026.05.21 from Homebrew.

## Load order in `kakrc` — this is load-bearing

`kakrc` is a single ordered script and several blocks only work in position:

1. `plug.kak` bootstrap (clones itself on first run)
2. `evaluate-commands %sh{ kak-lsp }` — must come **before** kak-ide, which
   extends `lsp_servers`
3. `source .../plugins/kak-ide/rc/kak-ide.kak` — must come **after** kak-lsp
   and **before** kak-tree-sitter, because it sets the `filetype` values
   tree-sitter keys its grammar choice off (notably `jsx`/`tsx`)
4. `kaktree`, then `kak-tree-sitter -dks --init`
5. `kak-ide-keymap-*-enable` calls
6. `fzf.kak`, then the leader-key and `user`-mode bindings

Critically, **`kakrc`'s own `map` calls run last and silently overwrite anything
kak-ide bound to the same key**. Kakoune reports no error for a duplicate `map`.
This has already caused shipped-but-unreachable bindings. `test/keymap.sh`
exists specifically to catch it, asserting against `debug mappings` (what
Kakoune actually resolved) rather than against source.

## Leader keys

`kakrc` swaps Kakoune's hard-coded `<space>` leader for `,`:

- `,` → `enter-user-mode user` (the leader menu)

The right-hand sides are raw keys, not commands, so they still work in counts
and macros. Submodes hang off `user`: `s` splits, `m` surround, `l` LSP,
`t` tree-sitter, `z` fzf, `y` system clipboard, `)`/`(` next/previous
(hunk, diagnostic, function).

There is no in-editor cheat sheet: `new-user-tips` and its `,?` binding were
removed. Use `:doc` and the leader menus, which read the real bindings.

## The kak-ide plugin

`plugins/kak-ide/` is the only locally-authored plugin (the others —
`plug.kak`, `fzf.kak`, `kaktree` — are vendored clones; don't edit them).
`rc/kak-ide.kak` is the entry point and sources its siblings in a fixed order:

    project → mux → languages → tooling → splits → files → surround → keymap

- **project.kak** — project-root detection. VCS root wins; otherwise walks up
  for `kak_ide_root_markers`. The shell logic lives in the `kak_ide_root_sh`
  option and is `eval`'d by consumers rather than duplicated. `fzf.kak`'s config
  block in `kakrc` keeps its own near-identical copy as `fzf_project_root_sh`.
- **mux.kak** — the terminal-multiplexer abstraction every pane/window/focus
  operation goes through. Two backends, chosen **per client at call time**:
  wezterm (when the client's env has `WEZTERM_PANE`) or tmux. Always read the
  pane id from `kak_client_env_*`, never the server's own environment — one
  session can have clients in several panes.
- **languages.kak** — gives `.jsx`/`.tsx` their own filetypes (Kakoune folds
  them into javascript/typescript, but tree-sitter picks its grammar from
  `filetype` and the typescript queries cannot parse JSX), then re-supplies the
  indent hooks, comment tokens and `lsp_language_id` that Kakoune only ships for
  the base filetypes.
- **tooling.kak** — resolves formatter/linter per project root (biome →
  eslint/prettier → LSP), cached per buffer. Format-on-save defaults on.
- **splits.kak** — a "split" is a second Kakoune *client* of the same session
  (`kak -c $kak_session`) in a multiplexer pane, so panes share buffers,
  registers and language servers. Kakoune has no internal splits.
- **surround.kak** — reads its delimiter as the next keypress, so any character
  works with no list of blessed characters. Note the file cannot contain a
  literal unpaired bracket: Kakoune counts brackets while parsing `%{…}` blocks
  even inside quoted strings, which is why the quote shortcuts use `%§…§`.
- **files.kak** — yazi in a zoomed pane. wezterm cannot hand back a pane's
  stdout, so the selection travels via `--chooser-file` and a background poll
  feeds `edit` commands back with `kak -p "$kak_session"`. Same shape fzf.kak uses.

## Tests

There is no runner; each is a standalone `sh` script under
`plugins/kak-ide/test/`. They drive a real headless Kakoune (`kak -ui json -e …`)
and assert on what it resolved.

    cd plugins/kak-ide/test
    ./make-fixture.sh          # build /tmp/kakide-fixture (required by smoke)
    ./smoke.sh                 # filetype/lang/indent/formatter resolution, ~15s
    ./smoke.sh --lsp           # also start servers, wait for diagnostics, ~90s
    ./keymap.sh                # binding assertions vs `debug mappings`, ~2s
    ./perf.sh                  # search latency, ~1s

Override the fixture path with `KAK_IDE_FIXTURE`, the perf repo with
`KAK_IDE_PERF_REPO`. `perf.sh` reports **SKIP**, never PASS, when no
sufficiently large repo is available, so a green run can't come from an
assertion that never ran.

## Dead-code cleanup (2026-08-27)

Commit `7bd30ab "kak: remove out-of-scope IDE features"` had deleted a large
part of kak-ide (pickers, command palette, multi-file rename, project
find/replace, goto-file/import resolution, DAP, workspace trust, the
Helix-parity keymap and the whole `bin/` directory) but left the docs and tests
describing them. That residue has now been removed:

- **`test/goto.sh`, `test/refactor.sh`** — deleted. Both exec'd helpers in
  `bin/`, so they exited 2 without running a single assertion.
- **`test/keymap.sh`** — the goto-table, Helix-mode and picker assertions were
  replaced with assertions on the bindings that actually ship (`,` leader,
  the `,s`/`,m` submodes, git/diagnostic bracket nav). It also asserts no
  duplicate keys per mode, which is the shadowing bug it exists to catch.
- **`test/smoke.sh`** — the probe for 14 deleted picker/palette commands and
  4 user modes now probes the 15 commands and 4 modes that exist. The palette
  index check is gone with the palette. CSS/HTML expectations corrected from
  `indentwidth=2` to `4`: nothing sets them, so they inherit the global `4`
  from `kakrc`.
- **`.kak-ide-palette`** — deleted. A 17KB cache nothing read or wrote after
  `kak-ide-palette-refresh` was removed. It was untracked.
- **`kak-ide-split-guard`** (`splits.kak`) — deleted. A self-described
  back-compat alias for `kak-ide-mux-guard` with no callers left.
- **`kak_ide_surround_open`** (`surround.kak`) — deleted. Declared but never
  read or written; the opening delimiter is carried in
  `kak_ide_surround_key`.
- **`plugins/kak-ide/README.md`** — rewritten from scratch (323 → 150 lines)
  against the shipped code. Every command and option it names was verified to
  exist.

Two live bugs surfaced by the same audit were fixed rather than documented:

- **`,z` was unbound.** The `fzf` user mode existed but nothing reached it;
  `kakrc` now maps `,z` to `fzf-mode`.
- **`new-user-tips` taught the wrong leader.** It said "everything hangs off
  `<space>`" and used `<space>x` throughout, from before the `,` swap — so the
  built-in help documented keys that no longer worked. Retargeted to `,`.
  (Since removed outright, along with `,?` — a hand-maintained cheat sheet
  that duplicated the leader menus was not worth keeping in sync.)

`plugins/.build/` is plug.kak's own generated cache, regenerated from `kakrc`;
it is tracked but should not be hand-edited.

## Verifying before you trust

`grep -r define-command plugins/kak-ide/rc/` is the authority on what exists.
Options declared with a multi-line `-docstring %{…}` put the name on the
*closing* line, so a naive `grep 'declare-option.*name'` will report a live
option as missing.
