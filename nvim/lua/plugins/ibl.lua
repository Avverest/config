vim.pack.add({ { src = "https://github.com/lukas-reineke/indent-blankline.nvim" } })

require("ibl").setup({
	indent = {
		char = "│",
	},
	scope = {
		enabled = true,
		char = "│",
		show_start = true,
		show_end = true,
		highlight = "IblScope",
		injected_languages = true,
	},
	exclude = {
		filetypes = {
			"help",
			"dashboard",
			"alpha",
			"neo-tree",
			"Trouble",
			"lazy",
			"mason",
			"notify",
			"toggleterm",
			"lazyterm",
		},
	},
	whitespace = {
		highlight = "IblWhitespace",
		remove_blankline_trail = true,
	},
})

vim.api.nvim_set_hl(0, "IblIndent", { fg = "#404040", nocombine = true })
vim.api.nvim_set_hl(0, "IblScope", { fg = "#606060", nocombine = true })
vim.api.nvim_set_hl(0, "IblWhitespace", { fg = "#303030", nocombine = true })
