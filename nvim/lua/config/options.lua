-- Основные настройки редактора
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.cmd.colorscheme("kanagawa")

local o = vim.o

-- Интерфейс
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.termguicolors = true
o.scrolloff = 6
o.splitright = true
o.splitbelow = true
o.winborder = "rounded" -- рамка у плавающих окон (hover, диагностика и т.д.)

-- Отступы
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.smartindent = true

-- Поиск
o.ignorecase = true
o.smartcase = true

-- Файлы
o.undofile = true
o.swapfile = false
o.updatetime = 300

-- Автодополнение (mini.completion, см. config/completion.lua).
-- fuzzy включает нечёткий подбор во встроенном popup; флага popup нет
-- намеренно — документацию рисует само окно info mini.completion,
-- второе окно от Vim дублировало бы её.
o.completeopt = "menuone,noselect,fuzzy"

-- Диагностика
vim.diagnostic.config({
	severity_sort = true,
	virtual_text = { current_line = false },
	float = { source = true },
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "✘",
			[vim.diagnostic.severity.WARN] = "▲",
			[vim.diagnostic.severity.INFO] = "»",
			[vim.diagnostic.severity.HINT] = "⚑",
		},
	},
})

-- Отступы по 2 пробела для веба и Lua
vim.api.nvim_create_autocmd("FileType", {
	pattern = {
		"html",
		"css",
		"scss",
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
		"json",
		"jsonc",
		"lua",
	},
	callback = function()
		vim.bo.shiftwidth = 2
		vim.bo.tabstop = 2
	end,
})

-- В Go — табы (стандарт gofmt)
vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function()
		vim.bo.expandtab = false
	end,
})
