# plain + tree-sitter faces.
#
# Shadows the built-in theme of the same name (Kakoune searches this
# directory before its runtime one). It sources the upstream file, so
# upstream stays the single source of truth for the palette and a
# Homebrew upgrade to Kakoune is picked up automatically.
source "%val{runtime}/colors/plain.kak"

# Upstream plain is deliberately almost colourless ("mostly default" -- it
# contains no rgb: value at all), so unlike the other overrides this one
# substitutes nothing. ts-bridge maps the tree-sitter faces onto the theme's
# own faces, and where those are `default` the result stays default too.
# That is the theme working as intended, not a gap to fill.
source "%val{config}/colors/ts-common/ts-bridge.kak"
source "%val{config}/colors/ts-common/ts-fill.kak"
