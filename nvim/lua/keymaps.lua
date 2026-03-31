local kmp = vim.keymap.set
local fzf = require("fzf-lua")

local opts = { noremap = true, silent = true }

kmp("n", "<CR>", ":")

kmp("n", "<leader>e", "<Cmd>Explore<CR>")

kmp("n", "<leader><leader>", fzf.files)
kmp("n", "<leader>/", fzf.live_grep)

kmp("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
kmp("n", "<Leader>fb", ":lua vim.lsp.buf.format()<CR>", opts)

-- tiny-code-action
kmp({ "n", "x" }, "<leader>a", function() require("tiny-code-action").code_action() end, opts)

-- conform
kmp("n", "<leader>fp", function()
	require("conform").format({ lsp_fallback = true })
end, { desc = "Format buffer" })

kmp("v", "<leader>fp", function()
	require("conform").format({ lsp_fallback = true })
end, { desc = "Format buffer" })

-- refactoring
kmp("n", "<leader>rn", function()
	return ":IncRename " .. vim.fn.expand("<cword>")
end, { expr = true, desc = "Rename symbol" })

-- Spectre (Массовая замена)
kmp("n", "<leader>sr", "<cmd>lua require('spectre').toggle()<CR>", { desc = "Spectre Search" })
kmp("n", "<leader>sw", "<cmd>lua require('spectre').open_visual({select_word=true})<CR>", { desc = "Spectre Word" })

-- Refactor
kmp({ "n", "x" }, "<leader>re", function() return require('refactoring').refactor('Extract Function') end, { expr = true })
kmp({ "n", "x" }, "<leader>rf", function() return require('refactoring').refactor('Extract Function To File') end, { expr = true })
kmp({ "n", "x" }, "<leader>rv", function() return require('refactoring').refactor('Extract Variable') end, { expr = true })
kmp({ "n", "x" }, "<leader>rI", function() return require('refactoring').refactor('Inline Function') end, { expr = true })
kmp({ "n", "x" }, "<leader>ri", function() return require('refactoring').refactor('Inline Variable') end, { expr = true })

kmp({ "n", "x" }, "<leader>rbb", function() return require('refactoring').refactor('Extract Block') end, { expr = true })
kmp({ "n", "x" }, "<leader>rbf", function() return require('refactoring').refactor('Extract Block To File') end, { expr = true })


-- Split window moving
kmp("n", "<leader>wh", "<C-w>h", opts)
kmp("n", "<leader>wj", "<C-w>j", opts)
kmp("n", "<leader>wk", "<C-w>k", opts)
kmp("n", "<leader>wl", "<C-w>l", opts)

-- Create split window
kmp("n", "<leader>wv", ":vsplit<CR>", opts)
kmp("n", "<leader>ws", ":split<CR>", opts)

-- === Изменение размера окон ===
-- Alt + h/j/k/l (или Option на Mac) для изменения размера
kmp("n", "<A-h>", "<C-w><", opts) -- Уменьшить ширину
kmp("n", "<A-l>", "<C-w>>", opts) -- Увеличить ширину
kmp("n", "<A-k>", "<C-w>+", opts) -- Увеличить высоту
kmp("n", "<A-j>", "<C-w>-", opts) -- Уменьшить высоту

-- === Управление окнами ===
-- Leader + q -> закрыть текущее окно
kmp("n", "<leader>wq", "<C-w>c", opts)
-- Leader + o -> оставить только текущее окно (закрыть остальные)
kmp("n", "<leader>wo", "<C-w>o", opts)

-- === Перемещение окон (свопами) ===
-- Ctrl + Shift + h/j/k/l для перемещения текущего окна в другую позицию
kmp("n", "<C-S-h>", "<C-w>H", opts)
kmp("n", "<C-S-j>", "<C-w>J", opts)
kmp("n", "<C-S-k>", "<C-w>K", opts)
kmp("n", "<C-S-l>", "<C-w>L", opts)
