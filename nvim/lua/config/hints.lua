-- Подсказки: что можно нажать дальше и что можно дописать в командной строке.
--
-- Две независимые части:
--   1. mini.clue   — всплывающее окно со списком продолжений после <leader>,
--                    g, z, ], [, ", <C-w> и т.д.;
--   2. командная строка — popup-меню дополнения для :команд.

-- ---------------------------------------------------------------------------
-- 1. Подсказки клавиш (mini.clue)
--
-- Модуль входит в mini.nvim, отдельный плагин не нужен.
-- Окно открывается, когда после нажатия префикса прошло delay мс и
-- последовательность ещё не завершена. Описания берутся из desc,
-- который проставлен у маппингов в остальных файлах конфига.
-- ---------------------------------------------------------------------------
local MiniClue = require("mini.clue")

MiniClue.setup({
	triggers = {
		-- Leader: normal, visual и operator-pending (например d<leader>…)
		{ mode = "n", keys = "<Leader>" },
		{ mode = "x", keys = "<Leader>" },

		-- localleader
		{ mode = "n", keys = "<LocalLeader>" },
		{ mode = "x", keys = "<LocalLeader>" },

		-- Встроенные префиксы Vim
		{ mode = "n", keys = "g" }, -- gd, gn, gp, gh, gl, gw, gr*
		{ mode = "x", keys = "g" },
		{ mode = "o", keys = "g" },
		{ mode = "n", keys = "z" }, -- сворачивание, скроллинг, орфография
		{ mode = "x", keys = "z" },
		{ mode = "n", keys = "]" }, -- ]b, ]d, ]q и прочие «вперёд»
		{ mode = "x", keys = "]" },
		{ mode = "n", keys = "[" }, -- «назад»
		{ mode = "x", keys = "[" },

		-- Окна: <C-w>s, <C-w>v, <C-w>o …
		{ mode = "n", keys = "<C-w>" },

		-- Регистры и метки
		{ mode = "n", keys = '"' },
		{ mode = "x", keys = '"' },
		{ mode = "i", keys = "<C-r>" },
		{ mode = "c", keys = "<C-r>" },
		{ mode = "n", keys = "'" },
		{ mode = "n", keys = "`" },
		{ mode = "x", keys = "'" },
		{ mode = "x", keys = "`" },

		-- Текстовые объекты и окружения от mini (ai/around, sa/sd/sr)
		{ mode = "n", keys = "s" },
		{ mode = "x", keys = "s" },

		-- Кириллические близнецы префиксов, чтобы окно открывалось и на
		-- русской раскладке: п = g, я = z, ы = s.
		-- Само окно при этом показывает английские буквы — см. фильтр ниже.
		{ mode = "n", keys = "п" },
		{ mode = "x", keys = "п" },
		{ mode = "o", keys = "п" },
		{ mode = "n", keys = "я" },
		{ mode = "x", keys = "я" },
		{ mode = "n", keys = "ы" },
		{ mode = "x", keys = "ы" },
	},

	clues = {
		-- Готовые описания встроенных клавиш Neovim
		MiniClue.gen_clues.builtin_completion(),
		MiniClue.gen_clues.g(),
		MiniClue.gen_clues.marks(),
		MiniClue.gen_clues.registers(),
		MiniClue.gen_clues.windows(),
		MiniClue.gen_clues.z(),

		-- Имена групп: без них в окне видно только голые буквы префиксов
		{ mode = "n", keys = "<Leader>c", desc = "+Код (LSP)" },
		{ mode = "x", keys = "<Leader>c", desc = "+Код: выделенное" },
		{ mode = "n", keys = "<Leader>s", desc = "+Поиск (mini.pick)" },
		{ mode = "n", keys = "<Leader>b", desc = "+Буферы" },
		{ mode = "n", keys = "<Leader>w", desc = "+Окна" },
		{ mode = "n", keys = "<Leader>t", desc = "+Вкладки" },
		{ mode = "n", keys = "<Leader>r", desc = "+Замена по проекту" },
		{ mode = "x", keys = "<Leader>r", desc = "+Замена: выделенное" },
	},

	window = {
		delay = 300, -- мс до появления окна; 0 — сразу, но мешает быстрым аккордам
		config = {
			width = "auto",
			border = "rounded",
		},
	},
})

-- ---------------------------------------------------------------------------
-- Окно подсказок показывает только английские буквы.
--
-- Зачем: langmap.lua дублирует каждую привязку на кириллицу (sf -> ыа,
-- gn -> пт). Для clue это обычные маппинги, и без фильтра окно показывало бы
-- каждое действие дважды — под английской и под русской буквой, с одним и тем
-- же описанием.
--
-- Что делаем, подменяя сборщик списка:
--   1. выкидываем кириллические дубликаты — остаются только английские буквы;
--   2. переводим кириллический запрос в английский, чтобы после «п» окно
--      показало продолжения от g (d, l, n, w...), а не от несуществующей «п».
-- Сами привязки не трогаем: нажатие «пт» по-прежнему сработает как gn.
-- ---------------------------------------------------------------------------
do
	-- Позиция в позицию с QWERTY, как в langmap.lua
	local ru =
		"йцукенгшщзхъфывапролджэячсмитьбю.ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,"
	local en = "qwertyuiop[]asdfghjkl;'zxcvbnm,./QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?"

	local to_en = {}
	local ru_chars = vim.fn.split(ru, "\\zs")
	local en_chars = vim.fn.split(en, "\\zs")
	for i, ru_char in ipairs(ru_chars) do
		to_en[ru_char] = en_chars[i]
	end

	-- Есть ли в строке хоть один кириллический символ
	local function has_cyrillic(keys)
		for _, char in ipairs(vim.fn.split(keys, "\\zs")) do
			if to_en[char] then
				return true
			end
		end
		return false
	end

	-- Перевод посимвольно; всё нераспознанное (<Cmd>, <C-w>, латиница) — как есть
	local function translate(keys)
		local out = {}
		for _, char in ipairs(vim.fn.split(keys, "\\zs")) do
			table.insert(out, to_en[char] or char)
		end
		return table.concat(out)
	end

	-- H — внутренняя таблица mini.clue, публичного хука для фильтрации нет.
	-- Достаём её через отладочные upvalue: modules mini.nvim держат H в
	-- замыкании своих функций.
	local ok, H = pcall(function()
		local i = 1
		while true do
			local name, value = debug.getupvalue(MiniClue.enable_all_triggers, i)
			if name == nil then
				break
			end
			if name == "H" then
				return value
			end
			i = i + 1
		end
	end)

	if ok and type(H) == "table" and type(H.clues_get_all) == "function" then
		local original = H.clues_get_all

		H.clues_get_all = function(mode)
			local clues = original(mode)

			local filtered = {}
			for keys, data in pairs(clues) do
				-- кириллический дубликат выкидываем, только если английский
				-- оригинал существует: иначе потеряли бы привязку, которая
				-- задана на русской букве и больше нигде не описана
				if has_cyrillic(keys) then
					local as_en = translate(keys)
					if clues[as_en] == nil then
						filtered[as_en] = data
					end
				else
					filtered[keys] = data
				end
			end

			return filtered
		end

		-- Запрос тоже переводим: после «п» окно должно показать продолжения
		-- ключа g (d, l, n, w...), а не искать несуществующий префикс «п».
		--
		-- Точки входа две: state_set — первая клавиша после триггера,
		-- state_push — каждая следующая. state_reset для этого не годится:
		-- он запрос очищает. H.clues_filter оборачивать тоже нельзя — он
		-- мутирует переданную таблицу, вычищая из неё несовпавшие ключи.
		--
		-- Побочный эффект полезный: state_exec выполняет накопленный запрос
		-- через nvim_feedkeys, то есть «пт» уйдёт в Neovim уже как gn.
		local function translate_query(query)
			if type(query) ~= "table" then
				return query
			end
			for idx, key in ipairs(query) do
				query[idx] = to_en[key] or key
			end
			return query
		end

		if type(H.state_set) == "function" then
			local original_set = H.state_set
			H.state_set = function(trigger, query)
				return original_set(trigger, translate_query(query))
			end
		end

		if type(H.state_push) == "function" then
			local original_push = H.state_push
			H.state_push = function(keys)
				return original_push(to_en[keys] or keys)
			end
		end
	else
		vim.notify(
			"mini.clue: не удалось включить фильтр кириллицы, окно покажет дубликаты",
			vim.log.levels.WARN
		)
	end
end

-- ---------------------------------------------------------------------------
-- 2. Подсказки по :командам
--
-- wildmenu показывает варианты дополнения, fuzzy добавляет нечёткий подбор:
-- :chekhe дополнится до :checkhealth.
--
-- wildoptions=pum рисует список вертикальным popup-меню над командной
-- строкой, а не строкой снизу. Меню рисует сам Neovim: в noice секция
-- popupmenu выключена (config/noice.lua).
-- ---------------------------------------------------------------------------
local o = vim.o

o.wildmenu = true
o.wildoptions = "pum,fuzzy"
o.wildmode = "longest:full,full" -- сначала общий префикс, потом перебор вариантов
o.pumheight = 10 -- не разворачивать список на пол-экрана
o.pummaxwidth = 60 -- узкий список: рядом остаётся место окну документации

-- Меню дополнения не должно ложиться на строку, где идёт набор.
--
-- Vim рисует popup под курсором, но если снизу не помещается pumheight
-- строк — переворачивает его вверх, и меню накрывает саму строку набора.
-- Одним scrolloff это не лечится: у конца файла курсор всё равно доезжает
-- до нижнего края, прокручивать дальше нечего.
--
-- Поэтому перед каждым открытием ужимаем pumheight до числа строк, которые
-- реально свободны под курсором. Меню становится ниже, но всегда снизу.
local pumheight_max = o.pumheight

vim.api.nvim_create_autocmd({ "InsertEnter", "CursorMovedI" }, {
	group = vim.api.nvim_create_augroup("PumFitBelow", { clear = true }),
	callback = function()
		-- Пока меню открыто, pumheight не трогаем: Vim читает его при
		-- открытии, а смена на лету только дёргает уже отрисованный список
		if vim.fn.pumvisible() == 1 then
			return
		end
		local space_below = vim.api.nvim_win_get_height(0) - vim.fn.winline()
		-- -1 на рамку самого popup; не опускаемся ниже 3 строк, иначе
		-- список становится бесполезным — там уж лучше вверх
		vim.o.pumheight = math.max(3, math.min(pumheight_max, space_below - 1))
	end,
})
o.wildignorecase = true -- :e READ… найдёт README

-- Мусор, который не нужен в дополнении путей
o.wildignore = table.concat({
	"*/node_modules/*",
	"*/.git/*",
	"*/target/*", -- rust
	"*/dist/*",
	"*/build/*",
	"*.o",
	"*.pyc",
}, ",")

-- В popup командной строки <C-n>/<C-p> вместо <Tab>/<S-Tab> — привычнее
-- и не конфликтует с longest:full, который на <Tab> дополняет префикс.
--
vim.keymap.set("c", "<C-n>", function()
	return vim.fn.wildmenumode() == 1 and "<C-n>" or "<Down>"
end, { expr = true, desc = "Следующий вариант дополнения" })

vim.keymap.set("c", "<C-p>", function()
	return vim.fn.wildmenumode() == 1 and "<C-p>" or "<Up>"
end, { expr = true, desc = "Предыдущий вариант дополнения" })
