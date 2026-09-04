require("dropbar").setup()

local api = require("dropbar.api")
local map = vim.keymap.set

map("n", "<leader>;", api.pick, { desc = "Breadcrumbs: перейти" })
