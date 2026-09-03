local wezterm = require("wezterm")
local fonts = require("fonts")
local themes = require("themes")
local getKeys = require("keys")

local config = wezterm.config_builder()

-- local font = fonts.monitor(fonts.lilex, 500)
local font = fonts.monitor(fonts.iosevka, 500)
-- local font = fonts.monitor(fonts.jb, 500)

-- local theme = themes.dark.trmnx_dark_gogh
local theme = themes.light.mexico

config.automatically_reload_config = true
config.window_close_confirmation = "NeverPrompt"
config.font = wezterm.font(font.family, { weight = font.weight })
config.font_size = font.size
config.line_height = font.height
config.color_scheme = theme
config.native_macos_fullscreen_mode = true

config.macos_window_background_blur = 10
config.window_background_opacity = 1
config.enable_tab_bar = false
config.window_decorations = "RESIZE"
config.window_padding = { top = 0, left = 0, right = 0, bottom = 0 }
config.leader = { key = ";", mods = "CTRL", timeout_ms = 500 }
config.keys = getKeys(wezterm)

-- Терминальная сетка всегда состоит из целых ячеек, поэтому остаток
-- экрана по высоте/ширине (до одной ячейки) физически не заполнить.
-- При font_size=23 и line_height=1.1 ячейка = 32pt, и этот остаток
-- виден как полоса. Единственное надёжное решение — красить его
-- в цвет фона схемы, чтобы он визуально сливался с контентом.
local scheme = wezterm.color.get_builtin_schemes()[theme]
local bg = scheme and scheme.background or "#000000"

config.colors = { background = bg }
config.window_frame = {
	font = wezterm.font({ family = font.family, weight = "Bold" }),
	font_size = 10,
	active_titlebar_bg = bg,
	inactive_titlebar_bg = bg,
}

return config
