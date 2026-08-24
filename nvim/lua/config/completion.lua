-- Автодополнение при наборе (mini.completion).
--
-- Зачем модуль, если в Neovim есть встроенное vim.lsp.completion: встроенное
-- всплывает только на «триггерных» символах сервера. У rust_analyzer это
-- `:`, `.`, `'`, `(` — после точки подсказки будут, а при наборе обычного
-- слова нет. mini.completion срабатывает на любой букве (с задержкой delay).
--
-- Работает в две ступени: сначала LSP, если тот молчит — fallback_action
-- (<C-n>, слова из буфера). Меню — нативный popup Vim, поэтому нечёткий
-- подбор даёт флаг fuzzy в completeopt (options.lua), а иконки видов
-- символов — MiniIcons.tweak_lsp_kind() из mini.lua.
--
-- Клавиши <CR>/<Tab>/<S-Tab> настроены не здесь, а в config/mini.lua через
-- mini.keymap (шаги pmenu_*): они делят эти клавиши с mini.pairs и сниппетами.
-- Ручной вызов меню: <C-Space> (на macOS эта комбинация может быть занята
-- системным переключением раскладки), fallback вручную — <A-Space>.

require("mini.completion").setup({
	delay = { completion = 100, info = 100, signature = 50 },

	window = {
		info = { border = "rounded" },
		signature = { border = "rounded" },
	},

	lsp_completion = {
		-- omnifunc, а не completefunc: оставляет completefunc свободным
		-- и соответствует привычному <C-x><C-o>
		source_func = "omnifunc",
	},

	-- Если LSP ничем не ответил — слова из текущего буфера
	fallback_action = "<C-n>",
})

-- Возможности клиента для lsp.lua: дополнение + резолв additionalTextEdits
-- (авто-импорты при подтверждении пункта)
local M = {}

function M.capabilities(extra)
	local caps = require("mini.completion").get_lsp_capabilities()
	return extra and vim.tbl_deep_extend("force", caps, extra) or caps
end

return M
