vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.autoformat = false

local o = vim.o

vim.opt.clipboard = "unnamedplus"

o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.termguicolors = true
o.scrolloff = 6
o.splitright = true
o.splitbelow = true
o.winborder = "rounded" -- рамка у плавающих окон (hover, диагностика и т.д.)

o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4

o.autoindent = true

o.ignorecase = true
o.smartcase = true

o.undofile = true
o.swapfile = false
o.updatetime = 300

-- popup: документация к выделенному пункту в отдельном окне рядом с меню
-- (completionItem/resolve). Раньше это окно приходилось открывать вручную
-- по <C-k>, выдирая внутренности mini.completion.
o.completeopt = "menuone,noselect,fuzzy,popup"

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

-- GDScript: официальный стиль Godot — отступы табами, а сам редактор при
-- сохранении сцены переписывает пробелы обратно в табы. Глобальный expandtab
-- из этого файла тут только мешает, поэтому выключаем его для gdscript.
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "gdscript", "gdshader" },
	callback = function()
		vim.bo.expandtab = false
		vim.bo.shiftwidth = 4
		vim.bo.tabstop = 4
	end,
})

-- Убрать r/o из formatoptions: без них Enter или o/O на закомментированной
-- строке больше не продолжает комментарий на новой строке. Отдельная
-- автокоманда на "FileType *" нужна потому, что ftplugin'ы (в том числе
-- встроенные) сами выставляют formatoptions при входе в filetype и
-- перезатирают любое значение, заданное один раз при старте.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "*",
	callback = function()
		vim.bo.formatoptions = vim.bo.formatoptions:gsub("[ro]", "")
	end,
})
