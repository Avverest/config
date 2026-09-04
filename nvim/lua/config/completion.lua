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

return M
