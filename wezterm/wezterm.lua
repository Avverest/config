local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.font = wezterm.font 'Hurmit Nerd Font Mono'
config.font_size = 18
config.color_scheme = 'Atelierdune (light) (terminal.sexy)'

return config
