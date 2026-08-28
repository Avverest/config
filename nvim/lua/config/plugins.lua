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

-- Каталог с запросами в runtimepath.
--
-- В ветке main плагин раскладывает queries/ не в своём корне, а на уровень
-- глубже — в runtime/queries/. В runtimepath же vim.pack добавляет только
-- корень плагина, поэтому vim.treesitter.query.get() ищет запрос по пути
-- <плагин>/queries/<язык>/indents.scm и не находит ничего.
--
-- Для подсветки это незаметно: highlights.scm плагин грузит сам, своим кодом.
-- А вот indents.scm читается штатным механизмом runtimepath, и без этой
-- строки get_indents() получает пустой набор правил и возвращает отступ 0 для
-- любой строки — то есть indentexpr есть, вызывается, но всегда отвечает
-- «нулевой уровень», и курсор на новой строке встаёт в первую колонку.
vim.opt.runtimepath:append(
	vim.fs.joinpath(vim.fn.stdpath("data"), "site/pack/core/opt/nvim-treesitter/runtime")
)

vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		-- запускаем подсветку только если для языка есть парсер
		local ok = pcall(vim.treesitter.start, args.buf)
		if ok then
			-- Отступ по дереву разбора. Он вытесняет smartindent и cindent
			-- (см. комментарий к отступам в config/options.lua), а когда для
			-- узла нет правила — возвращает -1, и тогда отступ берёт на себя
			-- autoindent.
			vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
		-- Ветки else тут нет намеренно: без парсера остаётся indentexpr,
		-- который проставил штатный ftplugin языка. Перетирать его нечем —
		-- у treesitter для этого языка правил всё равно нет.
	end,
})

-- ---------------------------------------------------------------------------
-- Форматтеры (conform.nvim)
-- ---------------------------------------------------------------------------
-- Форматтер для JS/TS/JSON выбирается по проекту, а не задаётся раз навсегда:
-- в одних проектах biome, в других prettier + eslint.
--
-- Признак — biome.json (или biome.jsonc) вверх по дереву от самого файла, тот
-- же маркер, по которому поднимается LSP-сервер biome (см. config/lsp.lua).
-- Благодаря этому редактор и линтер всегда сходятся во мнении: не бывает
-- случая, когда диагностику даёт biome, а форматирует prettier по своим
-- правилам, переставляя кавычки и запятые туда-обратно на каждое сохранение.
--
-- Список для conform возвращается функцией: она вызывается на каждое
-- форматирование с номером буфера, поэтому один Neovim на несколько проектов
-- в разных вкладках выберет каждому своё. vim.fs.root кэширует обход дерева,
-- отдельный кэш здесь не нужен.
local function js_formatter(bufnr)
	if vim.fs.root(bufnr, { "biome.json", "biome.jsonc" }) then
		return { "biome" }
	end
	return { "prettier" }
end

require("conform").setup({
	formatters_by_ft = {
		-- html/css/scss: biome умеет css, но html у него всё ещё за флагом,
		-- поэтому здесь prettier без вариантов
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
