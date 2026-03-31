vim.pack.add({
	{ src = "https://github.com/sainnhe/everforest" },
	{ src = "https://github.com/kungfusheep/mfd.nvim" },
	{ src = "https://github.com/metalelf0/black-metal-theme-neovim" },
	{ src = "https://github.com/oskarnurm/koda.nvim" },
	{ src = "https://github.com/navarasu/onedark.nvim" },
	{ src = "https://github.com/ankushbhagats/pastel.nvim" },
	{ src = "https://github.com/Verf/deepwhite.nvim" },
})

require("koda").setup({
	transparent = false,
	auto = true,
	cache = true,
	styles = {
		functions = { bold = true },
	}
})

require("deepwhite").setup({
	low_blue_light =  false
})
