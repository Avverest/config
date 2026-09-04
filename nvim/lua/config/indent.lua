require("ibl").setup({
	indent = {
		char = "│",
		tab_char = "│",
	},
	scope = {
		enabled = true,
		show_start = false, -- без подчёркивания первой и последней строки блока:
		show_end = false, -- в плотном коде это лишний шум
	},
	exclude = {
		-- к встроенному списку (help, man, checkhealth, gitcommit и прочее)
		-- добавляем то, что появилось из нашего конфига
		filetypes = { "netrw", "lazy", "mason", "snacks_dashboard" },
	},
})
