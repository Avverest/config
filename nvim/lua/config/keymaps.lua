-- Клавиши. LSP-маппинги по умолчанию в 0.11+:
--   grn — переименовать, gra — code action, grr — референсы,
--   gri — implementation, grt — type definition, gO — символы документа,
--   K — hover, <C-s> (insert) — signature help
local map = vim.keymap.set

-- Explore
map("n", "<leader>E", "<cmd>Explore<CR>")
map("n", "<CR>", ":")

-- Навигация LSP
map("n", "gd", vim.lsp.buf.definition, { desc = "Перейти к определению" })
map("n", "gD", vim.lsp.buf.declaration, { desc = "Перейти к объявлению" })

-- Диагностика
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Диагностика под курсором" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Диагностика в loclist" })

-- Форматирование (conform.nvim, с fallback на LSP)
map({ "n", "v" }, "<leader>f", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Форматировать буфер/выделение" })

-- Убрать подсветку поиска
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Перемещение между окнами
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Buffers
map("n", "ge", "G")

-- Row
map({ "n", "v" }, "mm", "%")
map({ "n", "v" }, "gh", "^")
map({ "n", "v" }, "gl", "$")
