-- Работа с буферами: список, переключение, закрытие.

local map = vim.keymap.set

-- ---------------------------------------------------------------------------
-- Список: mini.tabline рисует буферы строкой сверху.
-- setup() сам выставляет showtabline=2 и подменяет 'tabline'.
-- Иконки берутся из mini.icons (настроен в mini.lua).
-- ---------------------------------------------------------------------------
require("mini.tabline").setup({
	show_icons = true,
	tabpage_section = "right", -- счётчик вкладок справа, список буферов — от левого края
})

local MiniBufremove = require("mini.bufremove")
MiniBufremove.setup()

-- ---------------------------------------------------------------------------
-- Переключение
-- ---------------------------------------------------------------------------
-- gn — вперёд, gl — назад. Понимают счётчик: 3gn — на три буфера вперёд.
-- Внимание: gn в Vim уже занята встроенной командой «выделить следующее
-- совпадение поиска». Привязка сделана только для normal-режима, поэтому
-- идиома cgn (заменить следующее совпадение и повторять точкой) продолжает
-- работать — она использует gn в operator-pending режиме. См. :h gn.
-- gl свободна, её в Vim нет.
map("n", "gp", function()
	vim.cmd(vim.v.count1 .. "bprevious")
end, { desc = "Предыдущий буфер" })

map("n", "gn", function()
	vim.cmd(vim.v.count1 .. "bnext")
end, { desc = "Следующий буфер" })

map("n", "]b", "<cmd>bnext<CR>", { desc = "Следующий буфер" })
map("n", "[b", "<cmd>bprevious<CR>", { desc = "Предыдущий буфер" })
map("n", "]B", "<cmd>blast<CR>", { desc = "Последний буфер" })
map("n", "[B", "<cmd>bfirst<CR>", { desc = "Первый буфер" })
map("n", "<leader>`", "<C-^>", { desc = "Предыдущий активный буфер" })

-- Буферы, перечисленные в том же порядке, что и в tabline
local function listed_buffers()
	return vim.tbl_filter(function(buf)
		return vim.bo[buf].buflisted
	end, vim.api.nvim_list_bufs())
end

-- <leader>1..9 — прыжок к N-му буферу слева направо по tabline
for i = 1, 9 do
	map("n", "<leader>" .. i, function()
		local target = listed_buffers()[i]
		if target == nil then
			return vim.notify("Буфера №" .. i .. " нет", vim.log.levels.WARN)
		end
		vim.api.nvim_set_current_buf(target)
	end, { desc = "Перейти к буферу №" .. i })
end

-- ---------------------------------------------------------------------------
-- Закрытие: MiniBufremove убирает буфер, сохраняя раскладку окон.
-- Обычный :bdelete закрывает вместе с буфером и окно, где он показан.
-- При несохранённых изменениях спрашивает подтверждение (кроме варианта force).
-- ---------------------------------------------------------------------------
map("n", "<leader>bd", function()
	MiniBufremove.delete()
end, { desc = "Закрыть буфер" })

map("n", "<leader>bD", function()
	MiniBufremove.delete(0, true)
end, { desc = "Закрыть буфер, отбросив изменения" })

map("n", "<leader>bo", function()
	local current = vim.api.nvim_get_current_buf()
	local closed, kept = 0, 0
	for _, buf in ipairs(listed_buffers()) do
		if buf ~= current then
			-- изменённые пропускаем, иначе получим череду диалогов подтверждения
			if vim.bo[buf].modified then
				kept = kept + 1
			else
				MiniBufremove.delete(buf)
				closed = closed + 1
			end
		end
	end
	local msg = "Закрыто буферов: " .. closed
	if kept > 0 then
		msg = msg .. ", пропущено несохранённых: " .. kept
	end
	vim.notify(msg)
end, { desc = "Закрыть остальные буферы" })

-- ---------------------------------------------------------------------------
-- Список в окне выбора (mini.pick), с закрытием буфера прямо из него по <C-d>
-- ---------------------------------------------------------------------------
local function buffers_picker()
	local MiniPick = require("mini.pick")

	local close_current = function()
		local item = MiniPick.get_picker_matches().current
		if item == nil then
			return
		end
		MiniBufremove.delete(item.bufnr)
		-- убираем закрытый буфер из списка, чтобы окно не показывало мусор
		local rest = vim.tbl_filter(function(it)
			return it.bufnr ~= item.bufnr
		end, MiniPick.get_picker_items() or {})
		MiniPick.set_picker_items(rest)
	end

	MiniPick.builtin.buffers({}, {
		mappings = { close_buffer = { char = "<C-d>", func = close_current } },
	})
end

map("n", "<leader>bl", buffers_picker, { desc = "Список буферов (<C-d> — закрыть)" })
map("n", "<leader>sb", buffers_picker, { desc = "Поиск: буферы (<C-d> — закрыть)" })
