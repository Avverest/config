vim.pack.add({
	{ src = "https://github.com/windwp/nvim-autopairs" },
})

require("nvim-autopairs").setup({
	enable = true,
	bracketed = {
		enabled = true,
		suffix = ")",
		pair = "()",
		keymap = "<C-j>",
	},
	completion = {
		enable = true,
		documentation = true,
	},
	fast_wrap = {
		enabled = true,
		map = "<M-e>",
		chars = { "{", "[", "(", '"', "'" },
		pattern = [=[[%'%"%>%]%)%}%,]]=],
		end_key = "$",
		keys = "qwertyuiopzxcvbnmasdfghjkl",
		check_comma = true,
		highlight = "PmenuSel",
		highlight_grey = "Comment",
	},
	disable_filetype = { "TelescopePrompt", "spectre_panel", "lazy" },
	ignored_next_char = [=[[%w%%%'%"%`]]=],
	enable_moveright = true,
	enable_check_bracket_line = true,
	check_ts = true,
	ts_config = {
		lua = { string },
		javascript = { "template_string" },
		typescript = { "template_string" },
		javascriptreact = { "template_string" },
		typescriptreact = { "template_string" },
	},
	map_cr = true,
	map_bs = true,
	map_c_h = false,
	map_c_w = false,
})
