-- Основные настройки редактора
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.autoformat = false

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

o.autoindent = true

-- Поиск
o.ignorecase = true
o.smartcase = true

-- Файлы
o.undofile = true
o.swapfile = false
o.updatetime = 300

o.completeopt = "menuone,noselect,fuzzy"

-- Диагностика
vim.diagnostic.config({
	severity_sort = true,
	virtual_text = { current_line = false },
	float = { source = true },
	underline = true,
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "✘",
			[vim.diagnostic.severity.WARN] = "▲",
			[vim.diagnostic.severity.INFO] = "»",
			[vim.diagnostic.severity.HINT] = "⚑",
		},
	},
})

local diagnostic_underline = {
	DiagnosticUnderlineError = "#f7768e",
	DiagnosticUnderlineWarn = "#e0af68",
	DiagnosticUnderlineInfo = "#7dcfff",
	DiagnosticUnderlineHint = "#9ece6a",
}

local function set_diagnostic_underline()
	for group, color in pairs(diagnostic_underline) do
		vim.api.nvim_set_hl(0, group, { undercurl = true, sp = color })
	end
end

vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("DiagnosticUnderline", { clear = true }),
	callback = set_diagnostic_underline,
})

set_diagnostic_underline()

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
