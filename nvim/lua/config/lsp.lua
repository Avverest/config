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

		-- Рабочая директория — каталог самого файла, а не корень проекта.
		--
		-- При mode = "auto" (умолчание lspconfig) сервер отдаёт eslint корень
		-- репозитория, и тот на старте раскрывает flat-конфиг по всему дереву.
		-- Замер на evraz-app: 34 с от открытия файла до первой диагностики,
		-- притом что сам LspAttach проходит за 264 мс. Причина в конфиге
		-- проекта: FlatCompat тянет next/core-web-vitals и next/typescript,
		-- а те поднимают второй парсер TypeScript поверх того, что уже держит
		-- vtsls, плюс восемь плагинов.
		--
		-- mode = "location" сужает область до каталога открытого файла:
		-- eslint поднимается на нём одном, а не на 1793 файлах проекта.
		-- Конфиг ищется вверх по дереву как обычно, правила не теряются.
		--
		-- Проверка всего проекта остаётся за npm-скриптами (npm run lint) —
		-- в редакторе она и не нужна: диагностика показывается для буфера,
		-- который открыт.
		workingDirectory = { mode = "location" },
	},
})

-- ---------------------------------------------------------------------------
-- Клавиши LSP.
--
-- Маппинги буферные и вешаются на LspAttach: в буфере без сервера (обычный
-- текст, лог, файл незнакомого типа) клавиши остаются свободны и работают в
-- своём исходном значении, а не падают с «no client attached».
--
-- Что уже есть и здесь не дублируется:
--   grn — переименовать (перехвачен inc-rename, см. config/refactor.lua),
--   gra — code action, grr — референсы (picker, см. config/mini.lua),
--   gri — implementation, grt — type definition, gO — символы документа,
--   K — hover, <C-s> в insert — signature help,
--   gd / gD — определение и объявление (config/keymaps.lua),
--   <leader>e / <leader>q — диагностика (config/keymaps.lua),
--   <leader>ss / <leader>sS / <leader>sd — символы и диагностика через picker.
--
-- Ниже — то, чего в умолчаниях нет: группа <leader>c (code) для действий над
-- символом и управления самим сервером.
-- ---------------------------------------------------------------------------
local function lsp_keymaps(client, buf)
	local function map(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
	end

	-- Signature help в normal-режиме. В insert она уже висит на <C-s>
	-- (умолчание Neovim) и всплывает сама через mini.completion, но когда
	-- курсор стоит на вызове в normal, вызвать её было нечем.
	map("n", "<leader>ck", vim.lsp.buf.signature_help, "LSP: сигнатура функции")

	-- Hover-дублёр для тех случаев, когда K занята (например, в буфере с
	-- man-страницей или в плагинном окне со своим K).
	map("n", "<leader>ch", vim.lsp.buf.hover, "LSP: документация под курсором")

	-- Входящие вызовы: кто вызывает функцию под курсором. Полезнее референсов,
	-- когда символ — метод с распространённым именем.
	map("n", "<leader>ci", vim.lsp.buf.incoming_calls, "LSP: входящие вызовы")
	map("n", "<leader>co", vim.lsp.buf.outgoing_calls, "LSP: исходящие вызовы")

	-- Code action продублирован под <leader>ca: gra остаётся, но в группе
	-- <leader>c его видно в окне подсказок рядом с остальными действиями.
	map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "LSP: code action")

	-- Переименование — то же, что grn, через ту же inc-rename с предпросмотром.
	map("n", "<leader>cr", function()
		vim.api.nvim_feedkeys(vim.keycode("grn"), "m", false)
	end, "LSP: переименовать символ")

	-- Inlay hints: типы параметров и возвращаемых значений прямо в тексте.
	-- По умолчанию выключены — они сдвигают строку и мешают читать плотный
	-- код, поэтому включаются по требованию и только в текущем буфере.
	if client:supports_method("textDocument/inlayHint") then
		map("n", "<leader>cH", function()
			local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
			vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
			vim.notify("Inlay hints: " .. (enabled and "выкл" or "вкл"))
		end, "LSP: inlay hints вкл/выкл")
	end

	-- CodeLens: подсказки-действия над строкой («N references», «Run test»).
	-- Их надо явно обновлять — сервер не присылает их сам после правки.
	if client:supports_method("textDocument/codeLens") then
		map({ "n", "x" }, "<leader>cl", vim.lsp.codelens.run, "LSP: выполнить codelens")

		vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "TextChanged" }, {
			buffer = buf,
			callback = function()
				vim.lsp.codelens.refresh({ bufnr = buf })
			end,
		})
	end
end

-- Управление серверами — не зависит от буфера, поэтому вешается один раз.
-- :LspRestart, :LspInfo и :LspStop создаёт сам Neovim 0.11+.
vim.keymap.set("n", "<leader>cR", "<cmd>LspRestart<CR>", {
	desc = "LSP: перезапустить сервер",
})
vim.keymap.set("n", "<leader>cI", "<cmd>checkhealth vim.lsp<CR>", {
	desc = "LSP: состояние серверов",
})

-- Клавиша «починить все автофиксимые ошибки» — одна и та же <leader>cf для
-- eslint и biome. Маппинг буферный: вешается только там, где нужный сервер
-- реально подключился, поэтому в biome-проекте на неё сядет biome, в
-- eslint-проекте — eslint, и конфликта за клавишу нет.
--
-- Реализации разные. У eslint команду :LspEslintFixAll создаёт on_attach
-- самого сервера (см. lsp/eslint.lua в nvim-lspconfig). У biome такой команды
-- нет, поэтому его source.fixAll.biome запрашивается через обычный
-- code action с apply = true — меню не показывается, фикс применяется сразу.
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		lsp_keymaps(client, args.buf)

		if client.name == "eslint" then
			vim.keymap.set("n", "<leader>cf", "<cmd>LspEslintFixAll<CR>", {
				buffer = args.buf,
				desc = "ESLint: починить все автофиксимые ошибки",
			})
		elseif client.name == "biome" then
			vim.keymap.set("n", "<leader>cf", function()
				vim.lsp.buf.code_action({
					context = { only = { "source.fixAll.biome" }, diagnostics = {} },
					apply = true,
				})
			end, {
				buffer = args.buf,
				desc = "Biome: починить все автофиксимые ошибки",
			})
		end
	end,
})

-- Biome: линтер и форматтер для JS/TS/JSON в одном бинарнике, альтернатива
-- связке eslint + prettier.
--
-- Biome и eslint включены оба одновременно — это не конфликт и не дублирование
-- диагностики. Оба конфига в nvim-lspconfig объявлены с workspace_required =
-- true, а их root_dir возвращает nil, если рядом с файлом (вверх по дереву)
-- нет конфига именно этого инструмента: biome ищет biome.json/biome.jsonc,
-- eslint — eslint.config.* и .eslintrc*. Сервер без root_dir не стартует.
--
-- В итоге проект сам выбирает себе линтер: где лежит biome.json — поднимется
-- только biome, где eslint.config.js — только eslint. Ручного переключателя
-- не нужно. В проекте с обоими конфигами поднимутся оба, но это осознанная
-- настройка самого проекта, а не случайность конфига редактора.
--
-- В отличие от eslint здесь не нужен run = "onSave": biome написан на Rust
-- и линтует файл за единицы миллисекунд, отбирать процессор у tsserver во
-- время набора ему нечем (сравни с комментарием к eslint выше).
--
-- Переопределять в vim.lsp.config тут нечего: конфиг из nvim-lspconfig
-- (lsp/biome.lua) подходит как есть — он же сам находит бинарник в
-- node_modules/.bin проекта и падает обратно на глобальный.

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
	"biome", -- диагностика + фиксы там, где в проекте есть biome.json
	"emmet_ls", -- emmet для html/css
	"rust_analyzer",
	"gopls",
	"lua_ls",
	"jsonls", -- vscode-json-language-server
})

-- Автодополнением занимается mini.completion (config/completion.lua).
-- Нативное vim.lsp.completion здесь намеренно не включается: два меню на
-- одних и тех же данных мешали бы друг другу.
