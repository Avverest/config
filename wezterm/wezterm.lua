local wezterm = require 'wezterm'
local fonts = require 'fonts'
local themes = require 'themes'

local config = wezterm.config_builder()

config = {
  automatically_reload_config = true,
  window_close_confirmation = 'NeverPrompt',
  font = wezterm.font(fonts.hurmit.font, { weight = fonts.hurmit.weight }),
  font_size = 18,
  color_scheme = themes.belafonte_night,
  -- macos_window_background_blur = 30,
  -- window_background_opacity = 0.93,
  enable_tab_bar = false,
  window_decorations = 'RESIZE',
  line_height = 1.2,
  window_padding = {
    top = 0,
    left = 0,
    right = 0,
    bottom = 0,
  },
  window_frame = {
    -- Berkeley Mono for me again, though an idea could be to try a
    -- serif font here instead of monospace for a nicer look?
    font = wezterm.font({ family = 'Hurmit Nerd Font Mono', weight = 'Bold' }),
    font_size = 10,
  },
}

wezterm.on('update-status', function(window)
  -- Grab the utf8 character for the "powerline" left facing
  -- solid arrow.
  local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

  -- Grab the current window's configuration, and from it the
  -- palette (this is the combination of your chosen colour scheme
  -- including any overrides).
  local color_scheme = window:effective_config().resolved_palette
  local bg = color_scheme.background
  local fg = color_scheme.foreground

  print(wezterm.hostname())
  window:set_right_status(wezterm.format({
    -- First, we draw the arrow...
    { Background = { Color = 'none' } },
    { Foreground = { Color = bg } },
    { Text = SOLID_LEFT_ARROW },
    -- Then we draw our text
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = ' ' .. wezterm.hostname() .. ' ' },
  }))
end)

return config
