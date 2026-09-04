-- Настройки Neovide. Всё, что здесь, работает только в GUI — в терминальном
-- nvim этот файл сразу выходит. Часть настроек (шрифт, рамка окна, размер,
-- box-drawing) живёт не тут, а в ~/.config/neovide/config.toml: их читает
-- сам Neovide до старта Neovim.
if not vim.g.neovide then
	return
end

local g = vim.g

vim.g.neovide_opacity = 0.98
vim.g.neovide_normal_opacity = 0.98

-- Отступы от края окна: рамка buttonless прячет заголовок, кнопки лежат
-- поверх буфера — сверху нужно место, чтобы они не наезжали на текст.
g.neovide_padding_top = 0
g.neovide_padding_bottom = 0
g.neovide_padding_left = 0
g.neovide_padding_right = 0

-- Тема берётся из системной (light/dark), colorscheme.lua ставит flexoki-light
g.neovide_theme = "light"
g.neovide_opacity = 1.0
g.neovide_show_border = true -- граница окна на macOS

g.neovide_text_gamma = 0.0
g.neovide_text_contrast = 0.5
g.neovide_underline_stroke_scale = 1.0

g.neovide_floating_shadow = true
g.neovide_floating_z_height = 10
g.neovide_light_angle_degrees = 45
g.neovide_light_radius = 5
g.neovide_floating_corner_radius = 0.5
g.neovide_floating_blur_amount_x = 2.0
g.neovide_floating_blur_amount_y = 2.0

-- Анимации. Короткие: на длинных прокрутка «уплывает» от нажатия.
g.neovide_scroll_animation_length = 0.2
g.neovide_scroll_animation_far_lines = 1
g.neovide_position_animation_length = 0.1

-- Курсор без частиц: vfx_mode пустой, остаётся только плавное движение
g.neovide_cursor_animation_length = 0.05
g.neovide_cursor_short_animation_length = 0.03
g.neovide_cursor_trail_size = 0.3
g.neovide_cursor_antialiasing = true
g.neovide_cursor_animate_in_insert_mode = false
g.neovide_cursor_animate_command_line = false
g.neovide_cursor_smooth_blink = true
g.neovide_cursor_vfx_mode = ""

g.neovide_confirm_quit = true
g.neovide_remember_window_size = true
g.neovide_hide_mouse_when_typing = true
g.neovide_refresh_rate = 60
g.neovide_refresh_rate_idle = 5 -- когда окно не в фокусе
g.neovide_no_idle = false
g.neovide_input_ime = true

-- macOS: правый Alt как Meta, левый остаётся для ввода символов (ё, диакритика).
-- langmap.lua раскладку не трогает — здесь именно модификатор.
g.neovide_input_macos_option_key_is_meta = "only_right"

-- Масштаб шрифта по Cmd +/-/0. Базовый размер задан в config.toml.
local function scale(delta)
	return function()
		g.neovide_scale_factor = (g.neovide_scale_factor or 1.0) * delta
	end
end

local map = vim.keymap.set
map({ "n", "v", "i" }, "<D-=>", scale(1.1), { desc = "Neovide: увеличить шрифт" })
map({ "n", "v", "i" }, "<D-->", scale(1 / 1.1), { desc = "Neovide: уменьшить шрифт" })
map({ "n", "v", "i" }, "<D-0>", function()
	g.neovide_scale_factor = 1.0
end, { desc = "Neovide: сбросить масштаб" })

map({ "n", "v" }, "<D-c>", '"+y', { desc = "Копировать в системный буфер" })
map({ "n", "v" }, "<D-v>", '"+p', { desc = "Вставить из системного буфера" })
map("i", "<D-v>", "<C-r>+", { desc = "Вставить из системного буфера" })
map("c", "<D-v>", "<C-r>+", { desc = "Вставить из системного буфера" })
map("t", "<D-v>", [[<C-\><C-n>"+pi]], { desc = "Вставить из системного буфера" })

map({ "n", "v", "i" }, "<D-C-f>", function()
	g.neovide_fullscreen = not g.neovide_fullscreen
end, { desc = "Neovide: полный экран" })
