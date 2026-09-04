-- noice.nvim — командная строка попапом, сообщения уведомлениями.
--
-- Строки внизу нет вообще (cmdheight = 0): ввод : и поиск / ? идут в окно
-- по центру, а весь вывод — сообщения, ошибки, LSP-прогресс — всплывает
-- уведомлениями в правом нижнем углу.
--
-- Выключено то, что конфликтует с плагинами, рисующими свои окна:
--
--   * popupmenu — забирал меню автодополнения в режиме вставки и ставил
--     его через relative = "cursor" без проверки места снизу, из-за чего
--     окно ложилось на строку набора;
--   * lsp.hover / lsp.signature — рисовали второе окно поверх того, что
--     уже показывает нативный vim.lsp.buf.
--
-- Зависимость: nui.nvim. Отдельный notify-плагин не нужен: view "mini"
-- рисует уведомления сам (штатный backend noice поверх nui).

-- Собственно то, что убирает строку ввода команд: без этого Neovim держит
-- под буфером пустую строку команд, а попап noice рисуется поверх — место
-- снизу остаётся занятым зря. laststatus не трогаем — статусная строка
-- нужна.
vim.o.cmdheight = 0
vim.o.laststatus = 3
vim.o.showmode = false
vim.o.ruler = true

require("noice").setup({
	cmdline = {
		enabled = true,
		view = "cmdline_popup", -- окно по центру сверху; "cmdline" вернёт строку вниз
		format = {
			-- Иконка и подсветка зависят от того, что набрано первым символом.
			-- lang задаёт treesitter-подсветку внутри строки ввода.
			cmdline = { pattern = "^:", icon = ":", lang = "vim" },
			search_down = { kind = "search", pattern = "^/", icon = "/", lang = "regex" },
			search_up = { kind = "search", pattern = "^%?", icon = "?", lang = "regex" },
			filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
			lua = { pattern = { "^:%s*lua%s+", "^:%s*lua=", "^:%s*=" }, icon = "", lang = "lua" },
			help = { pattern = "^:%s*he?l?p?%s+", icon = "?" },
			-- inc-rename.nvim: пока печатаешь новое имя, видно предпросмотр.
			-- Работает потому, что noice не подменяет саму командную строку,
			-- а лишь перерисовывает её — inccommand остаётся живым.
			IncRename = { pattern = "^:%s*IncRename%s+", icon = "󰑕", conceal = true },
		},
	},

	-- Сообщения уходят в уведомления. Это обязательная пара к cmdheight = 0:
	-- без строки внизу их иначе просто негде показать.
	--
	-- view "mini" — компактная плашка в правом нижнем углу, гаснет сама
	-- через timeout. Не "notify": тот требует snacks.nvim или nvim-notify,
	-- а без них всё равно откатывается в "mini".
	messages = {
		enabled = false,
		view = "mini", -- обычные сообщения
		view_error = "mini",
		view_warn = "mini",
		view_history = "messages", -- :messages — во весь экран
		view_search = "virtualtext", -- «2/17» у строки поиска
	},

	notify = { enabled = false, view = "mini" }, -- vim.notify от плагинов

	-- Плашка "mini" вплотную прижата к краям: border.style = "none" и
	-- position.row = -1 в пресете плагина. padding у nui-рамки добавляет
	-- отступ внутри самого блока, row = -2 приподнимает его над нижним краем.
	views = {
		mini = {
			border = {
				style = "none",
				padding = { 0, 1 }, -- { по вертикали, по горизонтали }
			},
			position = { row = -2, col = "100%" },
		},
	},
  popupmenu = { enabled = false },

	-- Меню дополнения (и в режиме вставки, и для :команд) рисует сам Neovim.
	-- Со встроенным работают pumheight/pummaxwidth и подгонка высоты под
	-- свободное место снизу (config/hints.lua).

	lsp = {
		-- Индикатор загрузки LSP-серверов там же, в углу
		progress = {
			enabled = false,
			throttle = 1000 / 30,
			view = "mini",
		},
		-- Сообщения от серверов (window/showMessage) — уведомлением
		message = { enabled = false, view = "mini" },
		-- Окна hover и подсказок сигнатуры рисует нативный vim.lsp.buf:
		-- включённые здесь, они давали второе окно поверх первого.
		hover = { enabled = false },
		signature = { enabled = false },
		documentation = { enabled = false },
		override = { enabled = false }, -- разметку markdown не трогаем
	},

	routes = {
		-- Шум, который не стоит отдельной плашки.
		{
			-- «"file" 12L, 340B written» после каждого :w
			filter = { event = "msg_show", kind = "", find = "written" },
			opts = { skip = true },
		},
		{
			-- счётчик совпадений уже показан virtualtext'ом у строки поиска
			filter = { event = "msg_show", kind = "search_count" },
			opts = { skip = true },
		},
		{
			-- «-- ВСТАВКА --» и прочие индикаторы режима: при cmdheight = 0
			-- они не нужны, режим и так виден по курсору
			filter = { event = "msg_showmode" },
			opts = { skip = true },
		},
	},

	presets = {
		bottom_search = false, -- поиск тоже попапом, а не строкой снизу
		command_palette = true, -- нечего позиционировать: popupmenu штатный
		long_message_to_split = true, -- длинный вывод в split, а не в узкую плашку
		lsp_doc_border = false, -- сдвигал hover поверх строки набора
	},
})
