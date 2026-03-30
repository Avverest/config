local kmp = vim.keymap.set

vim.keymap.set("n", "<leader>e", "<Cmd>Explore<CR>")

local fzf = require("fzf-lua")

kmp("n", "<leader><leader>", fzf.files)
kmp("n", "<leader>/", fzf.live_grep)

local opts = { noremap = true, silent = true }

kmp("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
kmp("n", "<Leader>fb", ":lua vim.lsp.buf.format()<CR>", opts)
-- kmp({"n", "x" }, "<leader>a", "<cmd>lua vim.lsp.buf.code_action()<CR>" ,opts)
-- kmp("n", "<leader>fp", "<cmd>Prettier<CR>", opts)

-- tiny-code-action
kmp({ "n", "x" }, "<leader>a", function() require("tiny-code-action").code_action() end, opts)

-- conform
kmp("n", "<leader>fp", function()
	require("conform").format({ lsp_fallback = true })
end, { desc = "Format buffer" })

kmp("v", "<leader>fp", function()
	require("conform").format({ lsp_fallback = true })
end, { desc = "Format buffer" })
