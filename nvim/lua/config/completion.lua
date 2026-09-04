-- Автодополнение — встроенное в Neovim (vim.lsp.completion), без плагинов.
--
-- Включается в lsp.lua на LspAttach. Здесь — только возможности клиента
-- и подсказка сигнатуры, которой у встроенного механизма нет.

local M = {}

-- ---------------------------------------------------------------------------
-- Возможности клиента для lsp.lua.
--
-- resolveSupport.additionalTextEdits — авто-импорты: сервер присылает их не
-- в самом пункте меню, а только по completionItem/resolve, когда пункт
-- выделен. Без этого поля подтверждение пункта вставит имя, но не строку
-- импорта. Применяет их vim.lsp.completion на CompleteDone.
-- ---------------------------------------------------------------------------
function M.capabilities(extra)
	local caps = vim.lsp.protocol.make_client_capabilities()

	local item = caps.textDocument.completion.completionItem
	item.resolveSupport = {
		properties = { "documentation", "detail", "additionalTextEdits" },
	}

	return extra and vim.tbl_deep_extend("force", caps, extra) or caps
end

-- ---------------------------------------------------------------------------
-- Автотриггер на каждый печатный символ.
--
-- vim.lsp.completion.enable({autotrigger = true}) сам по себе показывает
-- меню только на triggerCharacters сервера — это «.», «:», «<», «/».
-- Набор обычного слова меню не откроет.
--
-- Штатный способ это изменить (:h lsp-autocompletion) — расширить сам
-- список triggerCharacters у клиента, причём ДО вызова enable: список
-- копируется в момент включения, а не читается на каждый символ.
--
-- Дебаунс писать не нужно: on_insert_char_pre внутри vim.lsp.completion
-- подстраивает паузу под время ответа сервера и сам дозапрашивает пункты,
-- когда сервер пометил список как isIncomplete.
-- ---------------------------------------------------------------------------
local printable = {}
for i = 32, 126 do
	table.insert(printable, string.char(i))
end

function M.enable(client, bufnr)
	if not client:supports_method("textDocument/completion") then
		return
	end

	local provider = client.server_capabilities.completionProvider
	if provider then
		provider.triggerCharacters = printable
	end

	vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
end

-- ---------------------------------------------------------------------------
-- Фолбэк на слова буфера.
--
-- Встроенный механизм показывает только то, что прислал LSP: нет сервера
-- (или он молчит) — нет и меню. mini.completion в этом случае звал <C-n>
-- через fallback_action; здесь то же самое, но своим автокомандом.
--
-- Слова ищет сам Vim по опции 'complete' (.,w,b,u,t — текущий буфер,
-- остальные окна, буферы в списке и выгруженные, плюс теги), поэтому
-- собирать словарь вручную не нужно.
--
-- Задержка больше, чем у LSP-запроса: если сервер отвечает, меню к этому
-- моменту уже открыто и фолбэк не вмешивается. Порядок именно такой —
-- иначе слова из буфера мигали бы перед списком от сервера.
-- ---------------------------------------------------------------------------
local fallback_timer

local function fallback_to_buffer_words()
	-- Меню уже открыто (ответил LSP или предыдущий фолбэк) — не мешаем
	if vim.fn.pumvisible() == 1 then
		return
	end

	-- Только в режиме вставки: за время задержки из него могли выйти
	local mode = vim.api.nvim_get_mode().mode
	if mode ~= "i" and mode ~= "ic" then
		return
	end

	-- Нужен непустой корень слова перед курсором, иначе <C-n> вывалит
	-- весь словарь буфера на пробеле или скобке
	local col = vim.api.nvim_win_get_cursor(0)[2]
	local before = vim.api.nvim_get_current_line():sub(1, col)
	if not before:match("[%w_]$") then
		return
	end

	vim.api.nvim_feedkeys(vim.keycode("<C-n>"), "n", false)
end

function M.enable_buffer_fallback(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	vim.api.nvim_create_autocmd("TextChangedI", {
		group = vim.api.nvim_create_augroup("CompletionFallback" .. bufnr, { clear = true }),
		buffer = bufnr,
		desc = "Слова из буфера, когда LSP ничего не предложил",
		callback = function(args)
			-- buftype проверяется здесь, а не при подписке: плагины часто
			-- выставляют его уже после создания буфера, поэтому на BufEnter
			-- он ещё пустой и служебный буфер выглядел бы обычным
			if vim.bo[args.buf].buftype ~= "" then
				return
			end

			if fallback_timer then
				fallback_timer:stop()
			end
			fallback_timer = vim.defer_fn(fallback_to_buffer_words, 250)
		end,
	})
end

-- ---------------------------------------------------------------------------
-- Подсказка сигнатуры при наборе.
--
-- Единственное, что делал mini.completion и чего нет во встроенном
-- механизме: окно с сигнатурой функции, всплывающее само после «(» или «,».
-- Окно рисует нативный vim.lsp.buf.signature_help, здесь только повод его
-- позвать — символ из signatureHelpProvider.triggerCharacters сервера.
--
-- focusable = false: иначе окно перехватывает <C-w> и остаётся висеть.
-- ---------------------------------------------------------------------------
local signature_timer

function M.enable_signature(client, bufnr)
	local provider = client.server_capabilities.signatureHelpProvider
	if not provider then
		return
	end

	local triggers = {}
	for _, c in ipairs(provider.triggerCharacters or {}) do
		triggers[c] = true
	end
	if vim.tbl_isempty(triggers) then
		return
	end

	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = vim.api.nvim_create_augroup("LspSignature" .. bufnr, { clear = true }),
		buffer = bufnr,
		desc = "Подсказка сигнатуры после ( и ,",
		callback = function()
			if not triggers[vim.v.char] then
				return
			end

			if signature_timer then
				signature_timer:stop()
			end
			signature_timer = vim.defer_fn(function()
				-- Меню дополнения важнее: два окна сразу перекрывают друг друга
				if vim.fn.pumvisible() == 1 then
					return
				end
				vim.lsp.buf.signature_help({
					focusable = false,
					close_events = { "InsertLeave", "CursorMoved", "BufHidden" },
				})
			end, 50)
		end,
	})
end

-- Фолбэк вешается на все обычные буферы: он нужен в первую очередь там,
-- где LSP нет вовсе, поэтому LspAttach для него не годится.
vim.api.nvim_create_autocmd("BufEnter", {
	group = vim.api.nvim_create_augroup("CompletionFallbackSetup", { clear = true }),
	desc = "Включить фолбэк на слова буфера",
	callback = function(args)
		M.enable_buffer_fallback(args.buf)
	end,
})

return M
