-- dropbar.nvim — breadcrumbs (путь по символам) в winbar сверху окна.
-- Источник данных: LSP documentSymbol, если сервер его отдаёт, иначе
-- treesitter, иначе просто путь к файлу — переключение источников
-- дефолтное, ничего не настраиваем.

require("dropbar").setup()

local api = require("dropbar.api")
local map = vim.keymap.set

-- Перейти к breadcrumbs и полистать их пикером (сам dropbar использует
-- fzf-native при наличии, иначе встроенный выбор).
map("n", "<leader>;", api.pick, { desc = "Breadcrumbs: перейти" })
