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

-- ---------------------------------------------------------------------------
-- vtsls: обход бага «Reduce of empty array with no initial value».
--
-- Сервер складывает число пунктов от своих провайдеров через reduce() без
-- начального значения. Там, где ни один из них ничего не дал — внутри
-- строки className в JSX — массив пуст, reduce бросает исключение, и
-- запрос падает с -32603.
--
-- На автодополнение это не влияет: классы от tailwindcss подставляются
-- как обычно (у каждого сервера свой запрос, падение одного не отменяет
-- ответ другого). Мешает только плашка с ошибкой на каждый символ.
--
-- Исправление в vtsls — PR yioneko/vtsls#318, одна строка: reduce(..., 0).
-- На сентябрь 2026 не влит, issue #329 открыт. Обработчик ниже гасит
-- только это сообщение и только у vtsls; остальные его ошибки видны.
-- Проверить при обновлении vtsls (сейчас 0.3.0) — и удалить, когда влит.
-- ---------------------------------------------------------------------------
local function vtsls_completion_handler(err, result, ctx)
	if err and err.message and err.message:find("Reduce of empty array", 1, true) then
		return nil, nil -- пустой ответ вместо ошибки: меню просто не откроется
	end
	return vim.lsp.handlers["textDocument/completion"](err, result, ctx)
end

vim.lsp.config("vtsls", {
	handlers = { ["textDocument/completion"] = vtsls_completion_handler },
	init_options = {
		hostInfo = "neovim",
		disableAutomaticTypingAcquisition = true,
	},
	settings = {
		vtsls = {
			autoUseWorkspaceTsdk = true,
			experimental = {
				completion = {
					enableServerSideFuzzyMatch = true,
					entriesLimit = 200,
				},
			},
		},
		typescript = {
			format = { enable = false }, -- форматирует prettier
			tsserver = { maxTsServerMemory = 8192 },
		},
		javascript = { format = { enable = false } },
	},
})

vim.lsp.config("eslint", {
	settings = {
		run = "onSave",
		workingDirectory = { mode = "location" },
	},
})

local function lsp_keymaps(client, buf)
	local function map(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
	end

	map("n", "<leader>a", vim.lsp.buf.code_action, "LSP: code action")
	map("n", "<leader>ck", vim.lsp.buf.signature_help, "LSP: сигнатура функции")

	map("n", "<leader>ch", vim.lsp.buf.hover, "LSP: документация под курсором")

	map("n", "<leader>ci", vim.lsp.buf.incoming_calls, "LSP: входящие вызовы")
	map("n", "<leader>co", vim.lsp.buf.outgoing_calls, "LSP: исходящие вызовы")

	map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "LSP: code action")

	map("n", "<leader>cr", function()
		vim.api.nvim_feedkeys(vim.keycode("grn"), "m", false)
	end, "LSP: переименовать символ")

	if client:supports_method("textDocument/inlayHint") then
		map("n", "<leader>cH", function()
			local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
			vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
			vim.notify("Inlay hints: " .. (enabled and "выкл" or "вкл"))
		end, "LSP: inlay hints вкл/выкл")
	end

	if client:supports_method("textDocument/codeLens") then
		map({ "n", "x" }, "<leader>cl", vim.lsp.codelens.run, "LSP: выполнить codelens")

		map("n", "<leader>cL", function()
			local enabled = vim.lsp.codelens.is_enabled({ bufnr = buf })
			vim.lsp.codelens.enable(not enabled, { bufnr = buf })
			vim.notify("Codelens: " .. (enabled and "выкл" or "вкл"))
		end, "LSP: codelens вкл/выкл")

		-- обновляется само: перерисовка и workspace/codeLens/refresh внутри vim.lsp.codelens
		vim.lsp.codelens.enable(true, { bufnr = buf })
	end
end

vim.keymap.set("n", "<leader>cR", "<cmd>LspRestart<CR>", {
	desc = "LSP: перезапустить сервер",
})
vim.keymap.set("n", "<leader>cI", "<cmd>checkhealth vim.lsp<CR>", {
	desc = "LSP: состояние серверов",
})

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		lsp_keymaps(client, args.buf)

		local completion = require("config.completion")
		completion.enable(client, args.buf)
		completion.enable_signature(client, args.buf)

		if client.name == "eslint" then
			vim.keymap.set("n", "<leader>cf", "<cmd>LspEslintFixAll<CR>", {
				buffer = args.buf,
				desc = "ESLint: починить все автофиксимые ошибки",
			})
		elseif client.name == "biome" then
			vim.keymap.set("n", "<leader>cf", function()
				vim.lsp.buf.code_action({
					context = { only = { "source.fixAll" }, diagnostics = {} },
					apply = true,
				})
			end, {
				buffer = args.buf,
				desc = "Biome: починить все автофиксимые ошибки",
			})
		end
	end,
})

-- Tailwind: классы в cva/clsx/cn и т.п., плюс подсветка в строках
vim.lsp.config("tailwindcss", {
	settings = {
		tailwindCSS = {
			experimental = {
				classRegex = {
					{ "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
					{ "cx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
					{ "cn\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
					{ "clsx\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
					"class(?:Name)?\\s*[:=]\\s*[\"'`]([^\"'`]*)",
				},
			},
		},
	},
})

-- GDScript: сервер живёт внутри самого Godot, а не ставится отдельно.
-- Редактор слушает TCP-порт (Editor Settings -> Network -> Language Server),
-- клиент из lspconfig просто подключается к 127.0.0.1:6005 — поэтому
-- подсказки и переход к определению работают только при запущенном Godot.
-- Другой порт задаётся переменной окружения GDScript_Port.
--
-- Чтобы Godot открывал файлы в этом Neovim, в Editor Settings -> Text Editor
-- -> External нужно включить Use External Editor и прописать путь к nvim с
-- аргументами: --server /tmp/godot.pipe --remote-send "<C-\><C-N>:n {file}<CR>{line}G{col}|"
-- а сам Neovim запускать как: nvim --listen /tmp/godot.pipe
vim.lsp.config("gdscript", {
	root_markers = { "project.godot" }, -- без .git: LSP без Godot всё равно бесполезен
})

vim.lsp.config("emmet_ls", {
	filetypes = { "html", "css", "scss", "sass", "less", "eruby", "htmldjango" },
})

vim.lsp.enable({
	"html", -- vscode-html-language-server
	"cssls", -- vscode-css-language-server
	"vtsls", -- @vtsls/language-server (JS + TS)
	"eslint", -- vscode-eslint-language-server: диагностика + фиксы
	"biome", -- диагностика + фиксы там, где в проекте есть biome.json
	"emmet_ls", -- emmet для html/css
	"rust_analyzer",
	"gopls",
	"lua_ls",
	"jsonls", -- vscode-json-language-server
	"tailwindcss", -- @tailwindcss/language-server: автодополнение классов
	"gdscript", -- встроен в Godot, подключение по TCP
	"gdshader_lsp", -- шейдеры Godot (.gdshader), ставится отдельно
})
