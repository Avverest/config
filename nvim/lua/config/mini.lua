-- mini.nvim — три запрошенные подсистемы:
--   mini.pick   — fuzzy-поиск файлов и текста (замена fzf/telescope)
--   mini.pairs  — автоматические парные скобки и кавычки
--   code action — отдельного модуля в mini.nvim нет. MiniPick.setup()
--                 подменяет vim.ui.select, поэтому нативный
--                 vim.lsp.buf.code_action() (клавиша gra) начинает
--                 показывать список действий в окне mini.pick.

local map = vim.keymap.set

-- Прыжок по экрану на gw (mini.jump2d).
-- Автодополнение — встроенное, настраивается в config/completion.lua.
require("mini.jump2d").setup({
	allowed_lines = { blank = false },
	mappings = { start_jumping = "gw" },
})

require("mini.surround").setup()

-- ---------------------------------------------------------------------------
-- Иконки: mini.pick рисует значки файлов только при активном mini.icons
-- ---------------------------------------------------------------------------
local MiniIcons = require("mini.icons")
MiniIcons.setup()
MiniIcons.tweak_lsp_kind() -- значки видов символов в меню автодополнения LSP

-- ---------------------------------------------------------------------------
-- Fuzzy-поиск: mini.pick + mini.extra (дополнительные источники)
-- Файлы и grep идут через ripgrep, он есть в PATH.
-- ---------------------------------------------------------------------------
local MiniPick = require("mini.pick")

MiniPick.setup({
	options = { use_cache = true },
	window = {
		-- окно по центру экрана вместо полосы снизу
		config = function()
			local height = math.floor(0.618 * vim.o.lines)
			local width = math.floor(0.618 * vim.o.columns)
			return {
				anchor = "NW",
				height = height,
				width = width,
				row = math.floor(0.5 * (vim.o.lines - height)),
				col = math.floor(0.5 * (vim.o.columns - width)),
			}
		end,
	},
})

local MiniExtra = require("mini.extra")
MiniExtra.setup()

-- Внутри окна выбора: <CR> — открыть, <C-s>/<C-v>/<C-t> — split/vsplit/вкладка,
-- <C-n>/<C-p> — вниз/вверх, <Tab> — предпросмотр, <C-x> — пометить, <Esc> — выход.
local pick, extra = MiniPick.builtin, MiniExtra.pickers

map("n", "<leader><leader>", pick.files, { desc = "Найти файл" })
map("n", "<leader>sf", pick.files, { desc = "Поиск: файлы" })
map("n", "<leader>sg", pick.grep_live, { desc = "Поиск: текст по проекту" })
-- <leader>sb (буферы) — в config/buffers.lua, там picker умеет ещё и закрывать
map("n", "<leader>sh", pick.help, { desc = "Поиск: справка" })
map("n", "<leader>sr", pick.resume, { desc = "Поиск: вернуться к прошлому" })
map("n", "<leader>sw", function()
	pick.grep({ pattern = vim.fn.expand("<cword>") })
end, { desc = "Поиск: слово под курсором" })

map("n", "<leader>so", extra.oldfiles, { desc = "Поиск: недавние файлы" })
map("n", "<leader>sk", extra.keymaps, { desc = "Поиск: клавиши" })
map("n", "<leader>sd", function()
	extra.diagnostic({ scope = "current" })
end, { desc = "Поиск: диагностика буфера" })
map("n", "<leader>sD", function()
	extra.diagnostic({ scope = "all" })
end, { desc = "Поиск: диагностика проекта" })
map("n", "<leader>ss", function()
	extra.lsp({ scope = "document_symbol" })
end, { desc = "Поиск: символы файла" })
map("n", "<leader>sS", function()
	extra.lsp({ scope = "workspace_symbol" })
end, { desc = "Поиск: символы проекта" })

-- Референсы и определения через picker вместо quickfix
map("n", "grr", function()
	extra.lsp({ scope = "references" })
end, { desc = "LSP: референсы (picker)" })

-- ---------------------------------------------------------------------------
-- Автопарные скобки: mini.pairs
-- ---------------------------------------------------------------------------
require("mini.pairs").setup({
	modes = { insert = true, command = true, terminal = false },
})

-- В Rust апостроф — это время жизни ('a, &'static), парная кавычка мешает.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "rust",
	callback = function(args)
		map("i", "'", "'", { buffer = args.buf, desc = "Апостроф без пары (lifetime)" })
	end,
})

require("mini.notify").setup({
	content = {
		format = function(notif)
			return notif.msg
		end,
	},
})

-- mini.git — источник данных для section_git() в mini.statusline (имя
-- ветки): без него секция всегда пустая, писать некому в vim.b.*_summary_string.
require("mini.git").setup()

require("mini.statusline").setup()

-- ---------------------------------------------------------------------------
-- mini.keymap — разруливает конфликт <CR> между автодополнением и mini.pairs.
-- Без этого mini.pairs забирает <CR> себе и ломает подтверждение выбора
-- в меню нативного LSP-автодополнения (см. :h MiniKeymap.map_multistep).
-- Шаги проверяются по порядку, первый подошедший выигрывает.
-- ---------------------------------------------------------------------------
local MiniKeymap = require("mini.keymap")
MiniKeymap.setup()

-- Меню автодополнения — встроенный popup Vim, поэтому шаги pmenu_*.
--   <CR>  — подтвердить выбранный пункт, иначе отдать <CR> в mini.pairs;
--   <Tab> — следующий пункт меню (вставляется сразу), иначе прыжок по
--           сниппету, иначе обычная табуляция.
MiniKeymap.map_multistep("i", "<CR>", { "pmenu_accept", "minipairs_cr" })
MiniKeymap.map_multistep("i", "<Tab>", { "pmenu_next", "vimsnippet_next" })
MiniKeymap.map_multistep("i", "<S-Tab>", { "pmenu_prev", "vimsnippet_prev" })
