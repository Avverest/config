-- Задачи: сборка, тесты, линтеры и прочие внешние команды (overseer.nvim).
--
-- Зачем отдельный инструмент, когда рядом есть :terminal (config/workspace.lua):
-- терминал — это одна живая сессия, за которой надо следить глазами. Overseer
-- держит список задач со статусами, умеет перезапустить последнюю одной
-- клавишей и сложить вывод в quickfix. Терминал остаётся для ручной возни в
-- шелле, overseer — для повторяемых команд проекта.
--
-- Откуда берутся задачи в списке <leader>or — из шаблонов. Встроенные
-- провайдеры сами находят package.json (npm/yarn/pnpm), Cargo.toml, Makefile,
-- justfile и .vscode/tasks.json, так что в типичном проекте настраивать
-- нечего. Свои шаблоны кладутся в lua/overseer/template/.

local overseer = require("overseer")

overseer.setup({
	-- Список задач снизу: он широкий и короткий, как quickfix, и не отнимает
	-- ширину у кода. Высота по умолчанию (8..20 строк) устраивает.
	task_list = {
		direction = "bottom",
	},

	-- Плавающие окна (форма ввода параметров задачи и просмотр вывода):
	-- border = nil означает «взять vim.o.winborder», а он выставлен в
	-- options.lua как rounded — то же, что у hover и диагностики.
	form = { border = nil },
	task_win = { border = nil },

	-- nvim-dap в сборке нет, патчить нечего.
	dap = false,
})

local map = vim.keymap.set

-- Группа <leader>o: t занято вкладками, c — кодом (LSP), поэтому ни tasks,
-- ни compile под букву не подходят.
map("n", "<leader>oo", "<cmd>OverseerToggle<CR>", { desc = "Задачи: список" })
map("n", "<leader>or", "<cmd>OverseerRun<CR>", { desc = "Задачи: запустить из шаблона" })
map("n", "<leader>oc", "<cmd>OverseerShell<CR>", { desc = "Задачи: произвольная команда" })
map("n", "<leader>oa", "<cmd>OverseerTaskAction<CR>", { desc = "Задачи: действие над задачей" })

-- Перезапуск последней задачи — самое частое действие в цикле «поправил код —
-- прогнал тесты». list_tasks по умолчанию сортирует свежие вперёд, поэтому
-- нужная задача всегда первая.
map("n", "<leader>ol", function()
	local tasks = overseer.list_tasks()
	if vim.tbl_isempty(tasks) then
		vim.notify("Ни одной задачи ещё не запускали", vim.log.levels.WARN)
		return
	end
	overseer.run_action(tasks[1], "restart")
end, { desc = "Задачи: перезапустить последнюю" })

-- Внутри окна списка работают свои клавиши: <CR> — меню действий над задачей,
-- o — открыть вывод, dd — убрать задачу, <C-q> — вывод в quickfix (дальше по
-- нему ходят ]q / [q из config/buffers.lua), p — предпросмотр, q — закрыть
-- список. Полный список — ? прямо в этом окне.
