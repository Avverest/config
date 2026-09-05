-- Клавиши. LSP-маппинги по умолчанию в 0.11+:
--   grn — переименовать, gra — code action, grr — референсы,
--   gri — implementation, grt — type definition, gO — символы документа,
--   K — hover, <C-s> (insert) — signature help
local map = vim.keymap.set

map("n", "<CR>", ":")

map("n", "gd", vim.lsp.buf.definition, { desc = "Перейти к определению" })
map("n", "gD", vim.lsp.buf.declaration, { desc = "Перейти к объявлению" })

map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Диагностика под курсором" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Диагностика в loclist" })

-- Прыжки по диагностике. ]d / [d есть в умолчаниях 0.11+ и ходят по всем
-- уровням подряд; ]e / [e — только по ошибкам, чтобы не спотыкаться о
-- предупреждения и подсказки на файле, где их сотни.
map("n", "]e", function()
	vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })
end, { desc = "Следующая ошибка" })

map("n", "[e", function()
	vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR })
end, { desc = "Предыдущая ошибка" })

map({ "n", "v" }, "<leader>f", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Форматировать буфер/выделение" })

map("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set('n', '<leader>cp', function()
  vim.fn.setreg('+', vim.fn.expand('%:.'))
end, { desc = "Скопировать путь файла" })
