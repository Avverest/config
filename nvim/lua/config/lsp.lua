-- LSP через нативный vim.lsp.config / vim.lsp.enable (Neovim 0.11+).
-- Базовые конфиги серверов берутся из nvim-lspconfig (каталог lsp/ в runtimepath),
-- ниже — только переопределения настроек.

-- Общие для всех серверов возможности клиента. Две добавки к умолчаниям:
--
-- 1. Операции с файлами. Neovim по умолчанию объявляет willRename/willCreate/
--    willDelete как false, поэтому серверы не предлагают эти методы, и
--    переименование файла в mini.files не обновляет ссылки на него
--    (см. config/refactor.lua).
-- 2. Возможности mini.completion — без них серверы не отдают сниппеты и
--    авто-импорты к пунктам автодополнения (см. config/completion.lua).
vim.lsp.config("*", {
	capabilities = require("config.completion").capabilities({
		workspace = {
			fileOperations = {
				dynamicRegistration = true,
				willCreate = true,
				willRename = true,
				willDelete = true,
				didCreate = true,
				didRename = true,
				didDelete = true,
			},
		},
	}),
})

-- Lua: подсказки по API Neovim
vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			workspace = {
				checkThirdParty = false,
				library = {
					vim.env.VIMRUNTIME,
					"${3rd}/luv/library",
				},
			},
			diagnostics = { globals = { "vim" } },
			format = { enable = false }, -- форматирует stylua через conform
		},
	},
})

-- Rust: проверка кода через clippy вместо cargo check
vim.lsp.config("rust_analyzer", {
	settings = {
		["rust-analyzer"] = {
			check = { command = "clippy" },
			cargo = { allFeatures = true },
		},
	},
})

-- Go: staticcheck и дополнительные анализы
vim.lsp.config("gopls", {
	settings = {
		gopls = {
			staticcheck = true,
			gofumpt = false,
			analyses = {
				unusedparams = true,
				unusedwrite = true,
			},
		},
	},
})

-- TypeScript/JavaScript: vtsls, а не typescript-language-server.
--
-- Причина замены — размер ответа на дополнение, а не скорость запуска.
-- tsserver кладёт в каждый ответ кандидатов на авто-импорт из всего
-- node_modules; на большом Next-проекте это 51 191 пункт и ~1 с на запрос,
-- при delay.completion = 100 мс меню просто не успевало за набором.
-- vtsls — обёртка над тем же локальным tsserver из node_modules проекта,
-- но умеет entriesLimit: авто-импорты остаются, ответ режется до лимита.
-- Замер на evraz-app: ~1000 мс -> ~20 мс на запрос.
--
-- Важно: ts_ls и vtsls нельзя включать одновременно — это два клиента
-- к одному tsserver, они дублируют диагностику и пункты меню.
vim.lsp.config("vtsls", {
	init_options = {
		hostInfo = "neovim",
		-- не искать и не докачивать @types для пакетов без типов:
		-- лишний обход package.json и поход в сеть на старте
		disableAutomaticTypingAcquisition = true,
	},
	settings = {
		vtsls = {
			-- брать TypeScript из node_modules проекта, а не свой встроенный:
			-- версия должна совпадать с той, которой собирается проект
			autoUseWorkspaceTsdk = true,
			experimental = {
				completion = {
					-- фильтрацию по набранному префиксу делает сервер,
					-- иначе лимит отрезал бы пункты до фильтрации
					enableServerSideFuzzyMatch = true,
					entriesLimit = 200,
				},
			},
		},
		typescript = {
			format = { enable = false }, -- форматирует prettier
			-- по умолчанию tsserver берёт ~3 ГБ и на большом проекте
			-- начинает выбрасывать программу из кэша и грузить её заново
			tsserver = { maxTsServerMemory = 8192 },
		},
		javascript = { format = { enable = false } },
	},
})

-- ESLint: отдельный сервер vscode-eslint-language-server (пакет
-- vscode-langservers-extracted), а не линтер eslint_d в nvim-lint.
--
-- Причина замены: nvim-lint умеет только запустить eslint и распарсить его
-- вывод в диагностику — code actions в этой схеме взяться неоткуда, поэтому
-- в меню `gra` и не было пункта «Fix all auto-fixable problems». Сервер к
-- каждой своей диагностике отдаёт фикс правила, «disable rule for this
-- line/file» и общий source.fixAll.eslint (он же :LspEslintFixAll).
--
-- По скорости это не откат к голому eslint: сервер держит инстанс eslint
-- вместе с разобранным flat-конфигом в своём node-процессе на корень
-- проекта — ровно то, ради чего в nvim-lint стоял демон eslint_d.
vim.lsp.config("eslint", {
	settings = {
		-- линт по сохранению, а не на каждое нажатие: иначе eslint отбирает
		-- процессор у tsserver ровно во время набора (по той же причине из
		-- автокоманды nvim-lint убран InsertLeave, см. config/plugins.lua)
		run = "onSave",
	},
})

-- Клавиша к :LspEslintFixAll. Команду создаёт on_attach самого сервера
-- (см. lsp/eslint.lua в nvim-lspconfig), поэтому маппинг вешается буферно
-- и только там, где eslint реально подключился.
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client and client.name == "eslint" then
			vim.keymap.set("n", "<leader>cf", "<cmd>LspEslintFixAll<CR>", {
				buffer = args.buf,
				desc = "ESLint: починить все автофиксимые ошибки",
			})
		end
	end,
})

-- Emmet раскрывает сокращения вида `div>ul>li` в разметку. В .tsx/.jsx он
-- отвечает почти на любое слово и засоряет меню дополнения, конкурируя с
-- vtsls, поэтому оставлен только там, где пишут собственно разметку и стили.
-- Список по умолчанию (см. lsp/emmet_ls.lua в nvim-lspconfig) включает
-- javascriptreact и typescriptreact — здесь он переопределяется целиком.
vim.lsp.config("emmet_ls", {
	filetypes = { "html", "css", "scss", "sass", "less", "eruby", "htmldjango" },
})

vim.lsp.enable({
	"html", -- vscode-html-language-server
	"cssls", -- vscode-css-language-server
	"vtsls", -- @vtsls/language-server (JS + TS), см. комментарий выше
	"eslint", -- vscode-eslint-language-server: диагностика + фиксы
	"emmet_ls", -- emmet для html/css
	"rust_analyzer",
	"gopls",
	"lua_ls",
	"jsonls", -- vscode-json-language-server
})

-- Автодополнением занимается mini.completion (config/completion.lua).
-- Нативное vim.lsp.completion здесь намеренно не включается: два меню на
-- одних и тех же данных мешали бы друг другу.
