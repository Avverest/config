local wezterm = require("wezterm")
local fonts = require("fonts")
local themes = require("themes")

local config = wezterm.config_builder()
local font = fonts.iosevka

local dark = themes.gogh.dark.azu
local light = themes.base.light.tokyonight_day

config = {
	automatically_reload_config = true,
	window_close_confirmation = "NeverPrompt",
	font = wezterm.font(font.family, { weight = font.weight }),
	font_size = font.size,
	line_height = font.height,
	color_scheme = dark,

	macos_window_background_blur = 10,
	window_background_opacity = 0.98,
	enable_tab_bar = false,
	window_decorations = "RESIZE",
	window_padding = {
		top = 3,
		left = 4,
		right = 4,
		bottom = 3,
	},
	window_frame = {
		-- Berkeley Mono for me again, though an idea could be to try a
		-- serif font here instead of monospace for a nicer look?
		font = wezterm.font({ family = font.family, weight = "Bold" }),
		font_size = 10,
	},
}

wezterm.on("update-status", function(window)
	-- Grab the utf8 character for the "powerline" left facing
	-- solid arrow.

	-- Grab the current window's configuration, and from it the
	-- palette (this is the combination of your chosen colour scheme
	-- including any overrides).
	local color_scheme = window:effective_config().resolved_palette
	local bg = color_scheme.background
	local fg = color_scheme.foreground

	-- print(wezterm.hostname())
	window:set_right_status(wezterm.format({
		-- First, we draw the arrow...
		{ Background = { Color = "none" } },
		{ Foreground = { Color = bg } },
		{ Text = SOLID_LEFT_ARROW },
		-- Then we draw our text
		{ Background = { Color = bg } },
		{ Foreground = { Color = fg } },
		{ Text = " " .. wezterm.hostname() .. " " },
	}))
end)

return config
