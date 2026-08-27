require("luna").setup({
	transparent = false,
	accent = 1.0, -- 0-1, blends syntax accents toward grey_light; 1 = full color
	plugins = {
		all = true, -- enable every plugin integration unconditionally
		auto = true, -- when plugins.all is false, autodetect via lazy.nvim
	},
	on_colors = function(colors) end,
	on_highlights = function(highlights, colors) end,
})

-- Kanagawa default options:
require("kanagawa").setup({
	compile = false, -- enable compiling the colorscheme
	undercurl = true, -- enable undercurls
	commentStyle = { italic = true },
	functionStyle = {},
	keywordStyle = { italic = true },
	statementStyle = { bold = true },
	typeStyle = {},
	transparent = false, -- do not set background color
	dimInactive = false, -- dim inactive window `:h hl-NormalNC`
	terminalColors = true, -- define vim.g.terminal_color_{0,17}
	colors = { -- add/modify theme and palette colors
		palette = {},
		theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
	},
	overrides = function(colors) -- add/modify highlights
		return {}
	end,
	theme = "wave", -- Load "wave" theme
	background = { -- map the value of 'background' option to a theme
		dark = "wave", -- try "dragon" !
		light = "lotus",
	},
})

-- setup must be called before loading
vim.cmd("colorscheme default")
