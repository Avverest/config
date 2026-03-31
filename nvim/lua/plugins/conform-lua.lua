vim.pack.add({{ src = "https://github.com/stevearc/conform.nvim" } })

local prettierOpts = { "prettierd", "prettier", stop_after_first = true }

require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		javascript = prettierOpts,
		typescript = prettierOpts,
		javascriptreact = prettierOpts,
		typescriptreact = prettierOpts,
		html = prettierOpts,
		css = prettierOpts,
		json = prettierOpts,
		yaml = prettierOpts,
		markdown = prettierOpts,
	}
})
