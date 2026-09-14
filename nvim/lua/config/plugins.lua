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
	{ src = "https://github.com/folke/noice.nvim" }, -- cmdline, поиск и сообщения в попапах
	{ src = "https://github.com/MunifTanjim/nui.nvim" }, -- зависимость noice.nvim
	{ src = "https://github.com/stevearc/overseer.nvim" }, -- запуск и список задач
	{ src = "https://github.com/Bekaboo/dropbar.nvim" }, -- breadcrumbs в winbar (LSP/treesitter)
	-- Автодополнение — встроенное, vim.lsp.completion (config/completion.lua)

	-- Themes
	{ src = "https://github.com/rebelot/kanagawa.nvim" },
	{ src = "https://github.com/kepano/flexoki-neovim" },
	{ src = "https://github.com/bluz71/vim-moonfly-colors", name = "moonfly" },
})

local ts_parsers = {
	"html",
	"css",
	"scss",
	"javascript",
	"typescript",
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
	"gdscript",
	"gdshader",
	"godot_resource", -- project.godot, *.tres, *.tscn
}
require("nvim-treesitter").install(ts_parsers)

-- Godot: project.godot встроенный ftplugin не распознаёт вовсе, а .gdshaderinc
-- знает не каждая версия. Оба — обычные ресурсные файлы Godot, парсер для них
-- называется godot_resource, тогда как filetype у .tscn/.tres — gdresource,
-- поэтому имя парсера приходится связать с filetype вручную.
vim.filetype.add({
	filename = { ["project.godot"] = "gdresource" },
	extension = { gdshaderinc = "gdshader" },
})
vim.treesitter.language.register("godot_resource", "gdresource")

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
		gdscript = { "gdformat" }, -- gdtoolkit; отступы табами, как требует Godot
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
	gdscript = { "gdlint" },
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

-- FileType, а не BufReadPost: последний срабатывает до определения filetype,
-- поэтому в колбэке vim.bo.filetype ещё пустой и ни один линтер не выбирается —
-- линтинг при открытии файла молча не работал, оставался только BufWritePost.
vim.api.nvim_create_autocmd({ "FileType", "BufWritePost" }, {
	callback = function(args)
		try_lint(args.buf)
	end,
})
