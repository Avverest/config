local overseer = require("overseer")

overseer.setup({
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

-- list_tasks сортирует свежие вперёд, поэтому нужная задача всегда первая
map("n", "<leader>ol", function()
	local tasks = overseer.list_tasks()
	if vim.tbl_isempty(tasks) then
		vim.notify("Ни одной задачи ещё не запускали", vim.log.levels.WARN)
		return
	end
	overseer.run_action(tasks[1], "restart")
end, { desc = "Задачи: перезапустить последнюю" })
