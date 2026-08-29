# greyscale + tree-sitter faces.
#
# Shadows the built-in theme of the same name (Kakoune searches this
# directory before its runtime one). It sources the upstream file, so
# upstream stays the single source of truth for the palette and a
# Homebrew upgrade to Kakoune is picked up automatically.
source "%val{runtime}/colors/greyscale.kak"

# ts-bridge aliases onto these, but upstream either leaves them undefined
# or defines them as bare `default` (no colour), which would leave the
# tree-sitter faces built on them unstyled. Point them at real colours.
set-face global function  keyword
set-face global variable  string
set-face global constant  value
set-face global operator  keyword
set-face global list      keyword
# `bullet` upstream is `+b` -- bold with no colour -- and ts-bridge maps the
# four ts_markup_list_* faces onto it, so they rendered unstyled.
set-face global bullet    keyword

# kak-tree-sitter highlights only via ts_* faces, which this theme predates.
source "%val{config}/colors/ts-common/ts-common.kak"
