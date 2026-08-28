-- Основные настройки редактора
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local o = vim.o

-- Интерфейс
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.termguicolors = true
o.scrolloff = 6
o.splitright = true
o.splitbelow = true
o.winborder = "rounded" -- рамка у плавающих окон (hover, диагностика и т.д.)

-- Отступы
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4

-- Курсор на новой строке встаёт на уровень вложенности, а не в первую колонку.
--
-- Механизмов отступа в Vim три, и они не складываются, а вытесняют друг друга
-- по приоритету: indentexpr > cindent > smartindent > autoindent. Как только
-- задан indentexpr, две следующие опции не работают вовсе.
--
-- Здесь indentexpr задан почти везде: config/plugins.lua вешает на FileType
-- indentexpr от treesitter для каждого языка, у которого нашёлся парсер. Он и
-- считает отступ — по дереву разбора, то есть с учётом синтаксиса, а не одних
-- скобок.
--
-- autoindent нужен как запасной вариант: indentexpr от treesitter возвращает
-- -1 там, где правило для узла не описано (внутри комментариев и строк, в
-- языках без своего indents.scm), и без autoindent в этот момент отступ не
-- берётся ниоткуда — курсор уезжает в первую колонку. С ним новая строка
-- наследует отступ предыдущей.
o.autoindent = true

-- smartindent намеренно НЕ включён. Его роль занимает indentexpr от
-- treesitter, а там, где парсера нет, он делает больше вреда, чем пользы:
-- жёстко зашитые правила для C сдвигают в первую колонку строки, начинающиеся
-- с #, что ломает заголовки в markdown и комментарии в конфигах.

-- Поиск
o.ignorecase = true
o.smartcase = true

-- Файлы
o.undofile = true
o.swapfile = false
o.updatetime = 300

-- Автодополнение (mini.completion, см. config/completion.lua).
-- fuzzy включает нечёткий подбор во встроенном popup; флага popup нет
-- намеренно — документацию рисует само окно info mini.completion,
-- второе окно от Vim дублировало бы её.
o.completeopt = "menuone,noselect,fuzzy"

-- Диагностика
vim.diagnostic.config({
	severity_sort = true,
	virtual_text = { current_line = false },
	float = { source = true },
	-- Подчёркивание проблемного места. Умолчание и так true, но выставлено
	-- явно: без него непонятно, что за подсветку кода отвечает именно эта
	-- настройка, а не тема или конкретный сервер.
	underline = true,
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "✘",
			[vim.diagnostic.severity.WARN] = "▲",
			[vim.diagnostic.severity.INFO] = "»",
			[vim.diagnostic.severity.HINT] = "⚑",
		},
	},
})

-- Как выглядит само подчёркивание.
--
-- underline = true включает подсветку групп DiagnosticUnderline*, но чем они
-- рисуются — дело темы. Здесь тема default (см. config/colorscheme.lua), а она
-- задаёт прямую тонкую линию бледно-розовым (#FFB3B9) на все четыре уровня:
-- на глаз ошибка почти не отличается от чистого кода, из-за чего кажется, что
-- линтер молчит, хотя диагностика на месте.
--
-- Ставим волнистую линию (undercurl) и разводим уровни по цвету. sp — цвет
-- самой линии, fg не трогаем: перекрасить текст значило бы затереть подсветку
-- синтаксиса от treesitter.
--
-- Через автокоманду, а не разовым вызовом: любая команда :colorscheme сбрасывает
-- все highlight-группы, и правки, применённые один раз на старте, пропали бы
-- при первом же переключении темы.
local diagnostic_underline = {
	DiagnosticUnderlineError = "#f7768e",
	DiagnosticUnderlineWarn = "#e0af68",
	DiagnosticUnderlineInfo = "#7dcfff",
	DiagnosticUnderlineHint = "#9ece6a",
}

local function set_diagnostic_underline()
	for group, color in pairs(diagnostic_underline) do
		vim.api.nvim_set_hl(0, group, { undercurl = true, sp = color })
	end
end

vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("DiagnosticUnderline", { clear = true }),
	callback = set_diagnostic_underline,
})

-- colorscheme в config/colorscheme.lua применяется раньше этого файла
-- (см. порядок require в init.lua), поэтому автокоманда на текущую тему уже
-- не сработает — задаём группы сразу.
set_diagnostic_underline()

-- Отступы по 2 пробела для веба и Lua
vim.api.nvim_create_autocmd("FileType", {
	pattern = {
		"html",
		"css",
		"scss",
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
		"json",
		"jsonc",
		"lua",
	},
	callback = function()
		vim.bo.shiftwidth = 2
		vim.bo.tabstop = 2
	end,
})

-- В Go — табы (стандарт gofmt)
vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function()
		vim.bo.expandtab = false
	end,
})
