-- Автодополнение при наборе (mini.completion).


require("mini.completion").setup({
	-- info = 10^7: окно документации само не всплывает. Иначе оно
	-- открывалось на каждом переборе пунктов, занимало низ экрана и меню
	-- переворачивалось вверх, закрывая строку набора. Показ — по <C-k>.
	delay = { completion = 100, info = 10, signature = 50 },


	-- lsp_completion = {
	-- 	-- omnifunc, а не completefunc: оставляет completefunc свободным
	-- 	-- и соответствует привычному <C-x><C-o>
	-- 	source_func = "omnifunc",
	-- },

	-- Если LSP ничем не ответил — слова из текущего буфера
	fallback_action = "<C-n>",
})

-- ---------------------------------------------------------------------------
-- Документация к пункту меню — по <C-k>, а не сама по себе.
--
-- Автопоказ выключен через delay.info выше. Публичной функции «показать
-- info» в mini.completion нет: окно рисует H.show_info_window, которое
-- дёргается из H.auto_info по событию CompleteChanged. Достаём H из
-- замыкания — тем же способом, что и для mini.clue в hints.lua.
--
-- Дальше нюанс: открытое окно закрылось бы на первом же CompleteChanged
-- (перебор пунктов). Поэтому пока окно открыто, auto_info подменяется
-- заглушкой — окно живёт до Esc.
-- ---------------------------------------------------------------------------
local function setup_info_key()
	local MiniCompletion = require("mini.completion")

	local ok, H = pcall(function()
		local i = 1
		while true do
			local name, value = debug.getupvalue(MiniCompletion.stop, i)
			if name == nil then
				break
			end
			if name == "H" then
				return value
			end
			i = i + 1
		end
	end)

	if not (ok and type(H) == "table" and type(H.show_info_window) == "function") then
		vim.notify(
			"mini.completion: не удалось привязать <C-k> к окну документации",
			vim.log.levels.WARN
		)
		return
	end

	local auto_info = H.auto_info
	local pinned = false

	-- Вернуть штатное поведение: окно закрыть, автопоказ разморозить
	local function unpin()
		if not pinned then
			return
		end
		pinned = false
		H.auto_info = auto_info
		H.close_action_window(H.info)
	end

	vim.keymap.set("i", "<C-k>", function()
		-- Вне меню дополнения клавиша не при делах
		if vim.fn.pumvisible() == 0 then
			return
		end

		-- Повторное нажатие убирает окно
		if pinned then
			unpin()
			return
		end

		-- Событие CompleteChanged mini.completion кладёт в H.info.event;
		-- без него show_info_window не знает, где рисовать окно.
		if H.info.event == nil then
			H.info.event = vim.v.event
		end

		pinned = true
		H.info.id = H.info.id + 1
		H.show_info_window(H.info.id)

		-- Заглушка вместо auto_info: перебор пунктов больше не гасит окно
		H.auto_info = function() end
	end, { desc = "Показать документацию к пункту (закрыть — Esc)" })

	-- Esc закрывает окно; если окна нет — обычный выход из режима вставки
	vim.keymap.set("i", "<Esc>", function()
		if pinned then
			unpin()
			return ""
		end
		return "<Esc>"
	end, { expr = true, desc = "Закрыть документацию или выйти из вставки" })

	-- Уход из вставки любым другим путём тоже снимает заморозку
	vim.api.nvim_create_autocmd("InsertLeave", {
		group = vim.api.nvim_create_augroup("CompletionInfoUnpin", { clear = true }),
		callback = unpin,
	})
end

setup_info_key()

-- Возможности клиента для lsp.lua: дополнение + резолв additionalTextEdits
-- (авто-импорты при подтверждении пункта)
local M = {}

function M.capabilities(extra)
	local caps = require("mini.completion").get_lsp_capabilities()
	return extra and vim.tbl_deep_extend("force", caps, extra) or caps
end

return M
