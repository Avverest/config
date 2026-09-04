local map = vim.keymap.set

-- Переименование символа: inc-rename показывает изменения по мере набора
require("inc_rename").setup({
	hl_group = "Substitute", -- чем подсвечивать предварительный вариант
	preview_empty_name = false,
	show_message = true, -- сводка «переименовано N вхождений в M файлах»
})

-- Заменяем стандартный grn: подставляем слово под курсором как начальное
-- значение, чтобы его можно было править, а не набирать заново.
map("n", "grn", function()
	return ":IncRename " .. vim.fn.expand("<cword>")
end, { expr = true, desc = "LSP: переименовать символ (с предпросмотром)" })

-- Поиск и замена по проекту (grug-far, на ripgrep)
require("grug-far").setup({
	-- иконки берём из mini.icons, он уже настроен в mini.lua
	icons = { enabled = true },
	windowCreationCommand = "botright vsplit",
})

map("n", "<leader>rr", function()
	require("grug-far").open()
end, { desc = "Замена по проекту" })

map("n", "<leader>rw", function()
	require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
end, { desc = "Замена по проекту: слово под курсором" })

map("n", "<leader>rf", function()
	-- ограничиться текущим файлом
	require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })
end, { desc = "Замена в текущем файле" })

map("x", "<leader>r", function()
	require("grug-far").with_visual_selection()
end, { desc = "Замена по проекту: выделенное" })

-- ---------------------------------------------------------------------------
-- Переименование файлов (mini.files): перед применением рассылает
-- workspace/willRenameFiles, чтобы серверы поправили ссылки.
--
-- Кто из наших серверов это реально умеет (проверено):
--   rust_analyzer — да, переписывает объявления mod;
--   gopls         — нет, но в Go это и не нужно: импорты ссылаются на пакет
--                   (каталог), а не на имя файла;
--   vtsls         — нет: сервер не объявляет willRename (проверено по
--                   server_capabilities.workspace.fileOperations). Как и у
--                   ts_ls до него. Для TypeScript пути в импортах после
--                   переименования файла придётся править самому, удобнее
--                   всего через <leader>rr (замена по проекту).
-- Клиентскую половину возможности включает vim.lsp.config("*") в lsp.lua —
-- без неё серверы молчат даже там, где поддержка есть.
-- ---------------------------------------------------------------------------
local MiniFiles = require("mini.files")

MiniFiles.setup({
	options = {
		permanent_delete = false, -- удалённое уходит в корзину внутри ~/.local/share/nvim
		-- ВАЖНО: не включать. При use_as_default_explorer = true mini.files
		-- вычищает автокоманды netrw (`autocmd! FileExplorer *`), и после этого
		-- предпросмотр inc-rename падает с E216, то есть grn перестаёт работать.
		-- Проверено бисектом: с false — переименование проходит, с true — нет.
		-- Каталоги при этом открывает netrw; mini.files всегда доступен по <leader>E.
		use_as_default_explorer = false,
		lsp_timeout = 3000, -- ждать сервер дольше: на больших проектах 1 сек мало
	},
	windows = {
		preview = true,
		width_focus = 40,
		width_preview = 60,
	},
})

-- Внутри окна: l — войти, h — наружу, = — применить изменения, q — закрыть,
-- g? — подсказка. Создание/удаление/переименование — обычным редактированием.
map("n", "<leader>E", function()
	-- открыть на текущем файле, если он есть на диске
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" or vim.uv.fs_stat(path) == nil then
		path = vim.uv.cwd()
	end
	MiniFiles.open(path)
	MiniFiles.reveal_cwd()
end, { desc = "Файловое дерево (переименование, перемещение)" })

-- Быстрое переименование текущего файла без открытия дерева
vim.api.nvim_create_user_command("Rename", function(opts)
	local old = vim.api.nvim_buf_get_name(0)
	if old == "" then
		return vim.notify("Буфер не связан с файлом", vim.log.levels.ERROR)
	end
	local new = opts.args ~= "" and opts.args or vim.fn.input("Новое имя: ", old, "file")
	if new == "" or new == old then
		return
	end
	-- vim.lsp.util.rename переносит файл и чинит имена буферов, но серверам
	-- ничего не сообщает — в отличие от mini.files. Для сложных случаев
	-- (обновление импортов) лучше переименовывать через <leader>E.
	vim.lsp.util.rename(old, vim.fn.fnamemodify(new, ":p"))
end, { nargs = "?", complete = "file", desc = "Переименовать текущий файл" })

-- Логи о том, что сервер поправил после переименования файла
vim.api.nvim_create_autocmd("User", {
	pattern = "MiniFilesActionRename",
	callback = function(args)
		vim.notify(
			("Переименовано: %s -> %s"):format(
				vim.fn.fnamemodify(args.data.from, ":t"),
				vim.fn.fnamemodify(args.data.to, ":t")
			)
		)
	end,
})
