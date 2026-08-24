-- Плагины через нативный менеджер vim.pack (Neovim 0.12+)
-- Управление: vim.pack.update() — обновить, vim.pack.del({...}) — удалить
vim.pack.add({
	{ src = "https://github.com/neovim/nvim-lspconfig" }, -- готовые конфиги LSP-серверов
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
	{ src = "https://github.com/stevearc/conform.nvim" }, -- форматтеры
	{ src = "https://github.com/mfussenegger/nvim-lint" }, -- линтеры
	{ src = "https://github.com/WTFox/luna.nvim" },
	{ src = "https://github.com/nvim-mini/mini.nvim", version = "stable" },
	{ src = "https://github.com/lukas-reineke/indent-blankline.nvim" }, -- линии отступов
	{ src = "https://github.com/smjonas/inc-rename.nvim" }, -- переименование с предпросмотром
	{ src = "https://github.com/MagicDuck/grug-far.nvim" }, -- замена по всему проекту
	-- Автодополнение — mini.completion (модуль mini.nvim, config/completion.lua)
	{ src = "https://github.com/rebelot/kanagawa.nvim" },
})

-- ---------------------------------------------------------------------------
-- Treesitter (ветка main: парсеры ставятся через install(), подсветка
-- включается вручную через vim.treesitter.start)
-- ---------------------------------------------------------------------------
local ts_parsers = {
	"html",
	"css",
	"scss",
	"javascript",
	"typescript",
	-- парсер для .tsx называется tsx, а не typescriptreact:
	-- typescriptreact — это имя filetype в Neovim, парсера с таким именем нет
	"tsx",
	"jsdoc",
	"rust",
	"go",
	"gomod",
	"gosum",
	"gowork",
	"lua",
	"json",
	"toml",
	"yaml",
	"markdown",
	"markdown_inline",
	"regex",
	"vim",
	"vimdoc",
	"query",
}
require("nvim-treesitter").install(ts_parsers)

vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		-- запускаем подсветку только если для языка есть парсер
		local ok = pcall(vim.treesitter.start, args.buf)
		if ok then
			vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})

-- ---------------------------------------------------------------------------
-- Форматтеры (conform.nvim)
-- ---------------------------------------------------------------------------
require("conform").setup({
	formatters_by_ft = {
		html = { "prettier" },
		css = { "prettier" },
		scss = { "prettier" },
		javascript = { "prettier" },
		javascriptreact = { "prettier" },
		typescript = { "prettier" },
		typescriptreact = { "prettier" },
		json = { "prettier" },
		jsonc = { "prettier" },
		rust = { "rustfmt" },
		lua = { "stylua" },
		go = { "goimports", "gofmt" },
	},
	format_on_save = function(bufnr)
		if vim.g.autoformat == false or vim.b[bufnr].autoformat == false then
			return
		end
		return { timeout_ms = 2000, lsp_format = "fallback" }
	end,
})

-- :FormatToggle — включить/выключить автоформат при сохранении
vim.api.nvim_create_user_command("FormatToggle", function()
	vim.g.autoformat = vim.g.autoformat == false
	vim.notify(
		"Автоформат при сохранении: " .. (vim.g.autoformat ~= false and "вкл" or "выкл")
	)
end, {})

-- ---------------------------------------------------------------------------
-- Линтеры (nvim-lint)
-- rust линтуется clippy через rust-analyzer (см. lsp.lua), отдельный не нужен
-- ---------------------------------------------------------------------------
local lint = require("lint")

-- ESLint здесь больше нет: он подключён как LSP-сервер (см. config/lsp.lua).
-- nvim-lint только парсит вывод линтера, из-за чего eslint давал диагностику,
-- но не давал ни одного code action — в том числе «Fix all auto-fixable
-- problems». Держать оба источника нельзя: диагностика удвоится.
lint.linters_by_ft = {
	css = { "stylelint" },
	scss = { "stylelint" },
	go = { "golangcilint" },
}

-- stylelint падает без конфига в проекте — запускаем его
-- только если конфиг найден вверх по дереву от файла
local linter_configs = {
	stylelint = {
		"stylelint.config.js",
		"stylelint.config.mjs",
		"stylelint.config.cjs",
		".stylelintrc",
		".stylelintrc.js",
		".stylelintrc.json",
		".stylelintrc.yml",
		".stylelintrc.yaml",
	},
}

local function try_lint(bufnr)
	local names = lint.linters_by_ft[vim.bo[bufnr].filetype] or {}
	local runnable = {}
	for _, name in ipairs(names) do
		local linter = lint.linters[name]
		local cmd = type(linter) == "table" and linter.cmd or nil
		local exe = type(cmd) == "function" and cmd() or cmd
		if exe and vim.fn.executable(exe) == 1 then
			local required = linter_configs[name]
			if not required or vim.fs.root(bufnr, required) then
				table.insert(runnable, name)
			end
		end
	end
	if #runnable > 0 then
		lint.try_lint(runnable)
	end
end

-- Без InsertLeave: линт запускался на каждый выход из режима вставки и
-- отнимал время у tsserver ровно тогда, когда тот считает дополнение.
-- Ошибки типов и так показывает LSP сразу, линтер нужен по факту сохранения.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
	callback = function(args)
		try_lint(args.buf)
	end,
})
