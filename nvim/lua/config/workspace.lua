-- Рабочая область: окна и вкладки.
--
-- Два уровня, у каждого своя группа привязок:
--   <leader>w — окна внутри вкладки: сплиты, ресайз, перемещение, терминал;
--   <leader>t — вкладки как отдельные раскладки под задачу, с именами.
--
-- Всё на встроенных возможностях Neovim, дополнительных плагинов нет.
-- Из внешнего используется только mini.pick — для списков окон и вкладок.
--
-- Прыжков по цифрам здесь намеренно нет: переключение последовательное
-- (tl/th, ]t/[t) или через пикер.

local map = vim.keymap.set

-- ---------------------------------------------------------------------------
-- Создание и закрытие. splitright/splitbelow уже выставлены в options.lua,
-- поэтому новое окно появляется справа или снизу от текущего.
-- ---------------------------------------------------------------------------
map("n", "<leader>ws", "<cmd>split<CR>", { desc = "Сплит горизонтально" })
map("n", "<leader>wv", "<cmd>vsplit<CR>", { desc = "Сплит вертикально" })
map("n", "<leader>wq", "<cmd>close<CR>", { desc = "Закрыть окно" })
map("n", "<leader>wo", "<cmd>only<CR>", { desc = "Закрыть остальные окна" })

-- ---------------------------------------------------------------------------
-- Раскладка: выравнивание, обмен местами, перенос к краю экрана.
-- ---------------------------------------------------------------------------
-- Тоже через :wincmd — по той же причине, что и переходы выше.
map("n", "<leader>w=", "<cmd>wincmd =<CR>", { desc = "Выровнять размеры окон" })
map("n", "<leader>wx", "<cmd>wincmd x<CR>", { desc = "Поменять местами с соседним" })
map("n", "<leader>wH", "<cmd>wincmd H<CR>", { desc = "Переместить окно влево" })
map("n", "<leader>wJ", "<cmd>wincmd J<CR>", { desc = "Переместить окно вниз" })
map("n", "<leader>wK", "<cmd>wincmd K<CR>", { desc = "Переместить окно вверх" })
map("n", "<leader>wL", "<cmd>wincmd L<CR>", { desc = "Переместить окно вправо" })

-- Ресайз. Шаг понимает счётчик: 10<M-l> расширит сразу на десять колонок.
map("n", "<M-h>", function()
	vim.cmd(vim.v.count1 .. "wincmd <")
end, { desc = "Сузить окно" })

map("n", "<M-l>", function()
	vim.cmd(vim.v.count1 .. "wincmd >")
end, { desc = "Расширить окно" })

map("n", "<M-j>", function()
	vim.cmd(vim.v.count1 .. "wincmd +")
end, { desc = "Увеличить высоту окна" })

map("n", "<M-k>", function()
	vim.cmd(vim.v.count1 .. "wincmd -")
end, { desc = "Уменьшить высоту окна" })

-- ---------------------------------------------------------------------------
-- Zoom: временно развернуть окно на весь экран.
--
-- Своей команды в Vim нет. Вместо сохранения и восстановления раскладки в
-- переменных открываем окно в новой вкладке (`tab split`): исходная вкладка
-- при этом не трогается вообще, и «вернуть как было» — это просто закрыть
-- вкладку. Флаг t:zoomed отличает такую вкладку от обычной.
-- ---------------------------------------------------------------------------
local function zoom_toggle()
	if vim.t.zoomed then
		return vim.cmd("tabclose")
	end
	if vim.fn.winnr("$") == 1 then
		return vim.notify("Окно и так одно", vim.log.levels.WARN)
	end
	vim.cmd("tab split")
	vim.t.zoomed = true
end

map("n", "<leader>wz", zoom_toggle, { desc = "Развернуть окно / вернуть" })
vim.api.nvim_create_user_command("WinZoom", zoom_toggle, { desc = "Развернуть окно / вернуть" })

-- ---------------------------------------------------------------------------
-- Терминал в сплите: встроенный :terminal, без плагинов.
--
-- Открывается всегда с краю (botright), чтобы не резать пополам то окно,
-- в котором сейчас работаешь.
-- ---------------------------------------------------------------------------
local function open_terminal(split_cmd)
	vim.cmd(split_cmd)
	vim.cmd("terminal")
end

map("n", "<leader>wt", function()
	open_terminal("botright 15split")
end, { desc = "Терминал снизу" })

map("n", "<leader>wT", function()
	open_terminal("botright vsplit")
end, { desc = "Терминал справа" })

-- Выход в normal-режим. Двойной <Esc>, а не одинарный: одинарный сломал бы
-- программы внутри терминала, которым <Esc> нужен самим (тот же nvim, htop).
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Выйти из терминала в normal" })

local term_group = vim.api.nvim_create_augroup("WorkspaceTerminal", { clear = true })

-- Номера строк и колонка знаков в выводе команд только мешают
vim.api.nvim_create_autocmd("TermOpen", {
	group = term_group,
	callback = function()
		vim.wo.number = false
		vim.wo.relativenumber = false
		vim.wo.signcolumn = "no"
		vim.cmd("startinsert")
	end,
})

-- При возврате в окно терминала сразу вставляем — иначе каждый раз
-- приходится жать i вручную.
vim.api.nvim_create_autocmd("BufEnter", {
	group = term_group,
	callback = function(args)
		if vim.bo[args.buf].buftype == "terminal" then
			vim.cmd("startinsert")
		end
	end,
})

-- ---------------------------------------------------------------------------
-- Вкладки — раскладки окон под задачу.
--
-- :tabnew открывает пустой буфер, что почти никогда не нужно: новая вкладка
-- заводится, чтобы разложить по-другому то, над чем работаешь. Поэтому
-- <leader>tn — это `tab split`, текущий файл переезжает в новую вкладку.
-- ---------------------------------------------------------------------------
map("n", "<leader>tn", "<cmd>tab split<CR>", { desc = "Новая вкладка с этим файлом" })
map("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "Закрыть вкладку" })
map("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "Закрыть остальные вкладки" })

map("n", "<leader>tl", "<cmd>tabnext<CR>", { desc = "Следующая вкладка" })
map("n", "<leader>th", "<cmd>tabprevious<CR>", { desc = "Предыдущая вкладка" })
map("n", "]t", "<cmd>tabnext<CR>", { desc = "Следующая вкладка" })
map("n", "[t", "<cmd>tabprevious<CR>", { desc = "Предыдущая вкладка" })

map("n", "<leader>tL", "<cmd>tabmove +1<CR>", { desc = "Вкладку вправо" })
map("n", "<leader>tH", "<cmd>tabmove -1<CR>", { desc = "Вкладку влево" })

-- ---------------------------------------------------------------------------
-- Имена вкладок.
--
-- Хранятся в переменной вкладки t:tabname. Сам tabline их не показывает:
-- его рисует mini.tabline и занят списком буферов, там только счётчик
-- «Tab 1/3». Имя видно в пикере вкладок (<leader>tt) — этого достаточно,
-- чтобы понять, какая вкладка под какую задачу.
-- ---------------------------------------------------------------------------
local function rename_tab(name)
	if name == nil or name == "" then
		vim.t.tabname = nil
		return vim.notify("Имя вкладки убрано")
	end
	vim.t.tabname = name
	vim.notify("Вкладка " .. vim.fn.tabpagenr() .. ": " .. name)
end

map("n", "<leader>tr", function()
	vim.ui.input({ prompt = "Имя вкладки: ", default = vim.t.tabname }, function(input)
		-- input == nil означает отмену: имя не трогаем
		if input ~= nil then
			rename_tab(input)
		end
	end)
end, { desc = "Переименовать вкладку" })

vim.api.nvim_create_user_command("TabRename", function(opts)
	rename_tab(opts.args)
end, { nargs = "?", desc = "Переименовать вкладку" })

-- ---------------------------------------------------------------------------
-- Списки окон и вкладок (mini.pick).
--
-- Пикер уже настроен в config/mini.lua — окно по центру экрана, поэтому
-- здесь задаём только items и choose.
--
-- Поля называем win/tabnr, а не bufnr и не path: по таким именам mini.pick
-- считает пункт буфером или файлом и пытается открыть его сам.
-- ---------------------------------------------------------------------------

-- Как показать буфер в списке: имя файла или пометка, что файла нет
local function buf_label(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		local buftype = vim.bo[buf].buftype
		return buftype == "terminal" and "[терминал]" or "[без имени]"
	end
	return vim.fn.fnamemodify(name, ":~:.")
end

local function windows_picker()
	local items = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		-- плавающие окна пропускаем: это подсказки и диагностика, прыгать
		-- по ним незачем, а само окно пикера тоже плавающее
		if vim.api.nvim_win_get_config(win).relative == "" then
			local nr = vim.api.nvim_win_get_number(win)
			table.insert(items, {
				text = nr .. ": " .. buf_label(vim.api.nvim_win_get_buf(win)),
				win = win,
			})
		end
	end

	require("mini.pick").start({
		source = {
			items = items,
			name = "Окна",
			choose = function(item)
				-- окно пикера в этот момент ещё открыто, поэтому переключаемся
				-- после его закрытия
				vim.schedule(function()
					if vim.api.nvim_win_is_valid(item.win) then
						vim.api.nvim_set_current_win(item.win)
					end
				end)
			end,
		},
	})
end

local function tabs_picker()
	local items = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local nr = vim.api.nvim_tabpage_get_number(tab)

		local label = vim.t[tab].tabname
		if label == nil or label == "" then
			-- имени нет — показываем файлы, открытые во вкладке
			local names = {}
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
				if vim.api.nvim_win_get_config(win).relative == "" then
					table.insert(names, buf_label(vim.api.nvim_win_get_buf(win)))
				end
			end
			label = table.concat(names, ", ")
		end

		table.insert(items, { text = nr .. ": " .. label, tabnr = tab })
	end

	require("mini.pick").start({
		source = {
			items = items,
			name = "Вкладки",
			choose = function(item)
				vim.schedule(function()
					if vim.api.nvim_tabpage_is_valid(item.tabnr) then
						vim.api.nvim_set_current_tabpage(item.tabnr)
					end
				end)
			end,
		},
	})
end

map("n", "<leader>ww", windows_picker, { desc = "Список окон" })
map("n", "<leader>tt", tabs_picker, { desc = "Список вкладок" })
