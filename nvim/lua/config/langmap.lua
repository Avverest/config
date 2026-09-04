-- Русская раскладка в normal/visual/operator-pending режимах, в два слоя:
-- 'langmap' для встроенных команд и дубликаты привязок ниже для map().
-- На insert-режим и командную строку не влияет.

-- Раскладка ЙЦУКЕН, позиция в позицию с QWERTY (включая знаки препинания:
-- ю — это точка «повторить», б — запятая, . — слеш «искать»).
local layouts = {
	{
		ru = "йцукенгшщзхъфывапролджэячсмитьбю.",
		en = "qwertyuiop[]asdfghjkl;'zxcvbnm,./",
	},
	{
		ru = "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,",
		en = 'QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>?',
	},
}

-- В значении 'langmap' эти символы обязаны быть экранированы обратным слешем
local function escape(char)
	return char:match('[;,"|\\]') and ("\\" .. char) or char
end

local pairs_list = {}
for _, layout in ipairs(layouts) do
	local ru = vim.fn.split(layout.ru, "\\zs")
	local en = vim.fn.split(layout.en, "\\zs")
	assert(#ru == #en, "раскладки разной длины: " .. #ru .. " vs " .. #en)
	for i, ru_char in ipairs(ru) do
		table.insert(pairs_list, escape(ru_char) .. escape(en[i]))
	end
end

vim.o.langmap = table.concat(pairs_list, ",")

-- Чтобы 'langmap' не применялся повторно к символам, которые уже выдала
-- привязка. В Neovim это и так по умолчанию, фиксируем явно.
vim.o.langremap = false

-- ---------------------------------------------------------------------------
-- Второй слой: дубликаты пользовательских привязок на кириллице.
--
-- 'langmap' покрывает только встроенные команды. Вопреки тому, что написано
-- в :h langmap, до пользовательских привязок он не доходит: нажатие «пт»
-- не вызывает привязку gn (проверено, langremap на это не влияет).
-- Поэтому для каждой привязки заводим её кириллический близнец.
-- ---------------------------------------------------------------------------

-- Латинский символ -> кириллический на той же клавише
local to_ru = {}
for _, layout in ipairs(layouts) do
	local ru = vim.fn.split(layout.ru, "\\zs")
	local en = vim.fn.split(layout.en, "\\zs")
	for i, en_char in ipairs(en) do
		to_ru[en_char] = ru[i]
	end
end

-- Переводит комбинацию клавиш в кириллицу. Работает побайтово: управляющие
-- байты (<C-d>, <Esc> и прочие) в таблице отсутствуют и остаются как есть.
local function to_cyrillic(lhs)
	local out, changed = {}, false
	for i = 1, #lhs do
		local char = lhs:sub(i, i)
		local ru_char = to_ru[char]
		if ru_char then
			changed = true
		end
		table.insert(out, ru_char or char)
	end
	return table.concat(out), changed
end

-- Служебные привязки плагинов: руками их не нажимают, дублировать нечего.
-- Ищем подстроку буквально: в lhs лежит именно текст "<Plug>", а keytrans
-- экранировал бы его в "<lt>Plug>" и проверка бы не сработала.
local function is_internal(lhs)
	return lhs:find("<Plug>", 1, true) ~= nil or lhs:find("<SNR>", 1, true) ~= nil
end

local function duplicate(keymaps, buffer)
	local made = 0
	for _, km in ipairs(keymaps) do
		local lhs_ru, changed = to_cyrillic(km.lhs)
		-- каждая кириллическая буква занимает 2 байта, а Neovim не принимает
		-- lhs длиннее MAXMAPLEN (50 байт)
		local too_long = #lhs_ru > 50
		if changed and not too_long and not is_internal(km.lhs) and vim.fn.maparg(lhs_ru, km.mode) == "" then
			-- одна отвергнутая привязка не должна срывать остальные
			local ok = pcall(vim.keymap.set, km.mode, lhs_ru, km.callback or km.rhs or "", {
				buffer = buffer,
				desc = km.desc and (km.desc .. " [ru]") or nil,
				silent = km.silent == 1,
				expr = km.expr == 1,
				nowait = km.nowait == 1,
				replace_keycodes = km.replace_keycodes == 1,
				remap = km.noremap == 0,
			})
			made = made + (ok and 1 or 0)
		end
	end
	return made
end

-- Только режимы команд. Insert и командную строку не трогаем: там кириллица
-- должна оставаться текстом.
local modes = { "n", "x", "o" }

local function sync()
	local made = 0
	for _, mode in ipairs(modes) do
		made = made + duplicate(vim.api.nvim_get_keymap(mode))
		made = made + duplicate(vim.api.nvim_buf_get_keymap(0, mode), 0)
	end
	return made
end

-- После загрузки всего конфига и плагинов, когда привязки уже расставлены
vim.api.nvim_create_autocmd("VimEnter", { callback = sync })

-- Привязки, появившиеся позже (например, буферные от LSP), можно догнать вручную
vim.api.nvim_create_user_command("LangmapSync", function()
	vim.notify("Продублировано привязок на кириллицу: " .. sync())
end, { desc = "Обновить кириллические дубликаты привязок" })
