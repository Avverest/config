local wezterm = require("wezterm")
local fonts = require("fonts")
local themes = require("themes")
local getKeys = require("keys")

local config = wezterm.config_builder()

local font = fonts.monitor(fonts.lilex, 400)

local dark = themes.gogh.dark.azu

config = {
	automatically_reload_config = true,
	window_close_confirmation = "NeverPrompt",
	font = wezterm.font(font.family, { weight = font.weight }),
	font_size = font.size,
	line_height = font.height,
	color_scheme = dark,

	macos_window_background_blur = 10,
	window_background_opacity = 1,
	enable_tab_bar = false,
	window_decorations = "RESIZE",
	window_padding = { top = 5, left = 5, right = 5, bottom = 5 },
	leader = { key = ";", mods = 'CTRL', timeout_ms = 500 },
	keys = getKeys(wezterm),
	window_frame = {
		font = wezterm.font({ family = font.family, weight = "Bold" }),
		font_size = 10,
	},
}

-- wezterm.on("update-status", function(window)
-- 	local color_scheme = window:effective_config().resolved_palette
-- 	local bg = color_scheme.background
-- 	local fg = color_scheme.foreground

-- 	-- print(wezterm.hostname())
-- 	window:set_right_status(wezterm.format({
-- 		-- First, we draw the arrow...
-- 		{ Background = { Color = "none" } },
-- 		{ Foreground = { Color = bg } },
-- 		{ Text = SOLID_LEFT_ARROW },
-- 		-- Then we draw our text
-- 		{ Background = { Color = bg } },
-- 		{ Foreground = { Color = fg } },
-- 		{ Text = " " .. wezterm.hostname() .. " " },
-- 	}))
-- end)

return config
