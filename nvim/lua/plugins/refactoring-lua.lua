vim.pack.add({
	{ src = "https://github.com/nvim-lua/plenary.nvim" },
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
	{ src = "https://github.com/smjonas/inc-rename.nvim" },
	{ src = "https://github.com/antosha417/nvim-lsp-file-operations" },
	{ src = "https://github.com/nvim-pack/nvim-spectre" },
	{ src = "https://github.com/ThePrimeagen/refactoring.nvim" },
})

require("inc_rename").setup()
require("lsp-file-operations").setup()
require("spectre").setup({
	default = {
		find = { cmd = "rg", options = { "--pcre2" } },
		replace = { cmd = "sed" },
	},
})

require("refactoring").setup({
	prompt_func_return_type = {
		go = false,
		java = false,

		cpp = false,
		c = false,
		h = false,
		hpp = false,
		cxx = false,
	},
	prompt_func_param_type = {
		go = false,
		java = false,

		cpp = false,
		c = false,
		h = false,
		hpp = false,
		cxx = false,
	},
	printf_statements = {},
	print_var_statements = {},
	show_success_message = false,
})
