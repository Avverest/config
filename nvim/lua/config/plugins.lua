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

local ts_parsers = {
	"html",
	"css",
	"scss",
	"javascript",
	"typescript",
	"tailwindCSS",
	"tsx",
	"jsdoc",
	"rust",
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

vim.opt.runtimepath:append(vim.fs.joinpath(vim.fn.stdpath("data"), "site/pack/core/opt/nvim-treesitter/runtime"))

vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		local ok = pcall(vim.treesitter.start, args.buf)
		if ok then
			vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})

local function js_formatter(bufnr)
	if vim.fs.root(bufnr, { "biome.json", "biome.jsonc" }) then
		return { "biome" }
	end
	return { "prettier" }
end

require("conform").setup({
	formatters_by_ft = {
		html = { "prettier" },
		css = { "prettier" },
		scss = { "prettier" },
		javascript = js_formatter,
		javascriptreact = js_formatter,
		typescript = js_formatter,
		typescriptreact = js_formatter,
		json = js_formatter,
		jsonc = js_formatter,
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

local lint = require("lint")

lint.linters_by_ft = {
	css = { "stylelint" },
	scss = { "stylelint" },
}

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

vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
	callback = function(args)
		try_lint(args.buf)
	end,
})
