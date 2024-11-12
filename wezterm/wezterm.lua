local wezterm = require 'wezterm'

local config = wezterm.config_builder()

local themes = {
  terminix_dark_gogh = 'Terminix Dark (Gogh)',
  tokyo_night_storm_gogh = 'Tokyo Night Storm (Gogh)',
  tokyonight_day = 'tokyonight_day',
}

-- config.font = wezterm.font 'Hurmit Nerd Font Mono'
config = {
  font = wezterm.font(
    'JetBrainsMono Nerd Font Mono',
    { weight='Light' }
  ),
  font_size = 16,
  color_scheme = themes.tokyonight_day,
  -- macos_window_background_blur = 30,
  -- window_background_opacity = 0.93,
  enable_tab_bar = false,
  window_decorations = 'RESIZE',
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
