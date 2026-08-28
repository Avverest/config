-- Neovim 0.12+ config, использует нативный менеджер плагинов vim.pack
require("config.plugins")
require("config.colorscheme")
require("config.options")
require("config.keymaps")
require("config.langmap")
require("config.mini") -- после options.lua: нужен уже выставленный mapleader
require("config.buffers")
require("config.workspace") -- окна и вкладки; до hints.lua: clue берёт desc
require("config.indent")
require("config.refactor")
require("config.completion") -- до lsp.lua: оттуда берутся возможности клиента
require("config.lsp")
require("config.hints") -- после всех маппингов: clue берёт описания из desc
require("config.perf") -- :PerfOn / :PerfReport — замеры, поведение не меняют
