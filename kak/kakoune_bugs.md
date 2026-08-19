# Kakoune annoyances — status

## 1. Cannot close buffer — FIXED

`delete-buffer` refuses a buffer with unsaved changes ("buffer 'x' is
modified") and offers nothing further, so it looks unclosable unless you
already know to type `:delete-buffer!`.

`kak-ide-close-buffer` catches that and asks: **w** write and close,
**d** discard, **c** cancel. Bound to `<space>B`.

`kakrc`'s plain `,d` → `:delete-buffer` is unchanged — it is your binding and
predates this (plan §8 rule 4).

## 2. Preview / file-search window too slow — FIXED

Two separate causes, both measured on a 25,817-file tree:

- The grep picker ran `rg ''` — an empty pattern matching *every line of every
  file* — and handed the lot to fzf: **9.47M lines / 1.02 GB / 1.50 s** before
  fzf even started. Now `--disabled` + `--bind change:reload:` re-runs `rg` per
  keystroke, so only matches move: **0.024 s** startup, 0.03–0.13 s per query.
- fzf opened in a separate WezTerm *window* (`windowing_placement` defaulted to
  `window`), and preview was blank because the `bat`-absent fallback was a bare
  `cat` with no argument. Both fixed earlier: a 70% pane split, `cat {}`.

On this config's own tree both pickers now start in **under 30 ms**; the pane
split itself costs ~50 ms.

## 3. Hotkeys to move between buffers (Helix `gn`/`gp`) — FIXED, different keys

`gn`/`gp` are **not achievable**. Kakoune's goto mode is C++ and only dispatches
keys it already knows: `map global goto n` is accepted, and even shows up in
`debug mappings`, but pressing `gn` gives "key not mapped". Reproduced in a bare
`kak -n` with no config, so it is upstream behaviour, not a conflict here.
(`gD`/`gi` work precisely because those *are* goto keys.)

Buffer navigation instead lives on:

| Key | Action |
|---|---|
| `]b` / `[b` | next / previous buffer (with `]c` hunks, `]d` diagnostics, `]f` functions) |
| `<space>n` / `<space>p` | next / previous buffer |
| `<space>b` | buffer picker |
| `ga` | last buffer — Kakoune's own, same as Helix's `ga` |
