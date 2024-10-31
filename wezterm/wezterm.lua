local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.font = wezterm.font 'Hurmit Nerd Font Mono'
config.font_size = 17
config.color_scheme = 'Rose Pine'

config.window_background_opacity = 0.9
config.macos_window_background_blur = 30

config.window_decorations = 'RESIZE'
config.window_padding = {
  left = 0,
  right = 0,
  bottom = 0,
  top = 0,
}

config.window_frame = {
  -- Berkeley Mono for me again, though an idea could be to try a
  -- serif font here instead of monospace for a nicer look?
  font = wezterm.font({ family = 'Hurmit Nerd Font Mono', weight = 'Bold' }),
  font_size = 15,
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
    { Text = 'test' .. wezterm.hostname() .. 'test2 ' },
  }))
end)

-- config.use_fancy_tab_bar = true
-- config.show_tabs_in_tab_bar = true
-- config.show_new_tab_button_in_tab_bar = false

return config
