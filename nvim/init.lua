require("plugins")
require("lsp")
require("config")
require("autocmd")
require("keymaps")

local changeBackground = function(background)
	vim.o.background = background
	if background == "dark" then
		vim.cmd("colorscheme koda-dark")
		vim.api.nvim_set_hl(0, "IblIndent", { fg = "#404040", nocombine = true })
		vim.api.nvim_set_hl(0, "IblScope", { fg = "#606060", nocombine = true })
		vim.api.nvim_set_hl(0, "IblWhitespace", { fg = "#303030", nocombine = true })
	else
		vim.cmd("colorscheme deepwhite")
		require('lualine').setup({ options = { theme = 'deepwhite', } })
	end
end

changeBackground("dark")
