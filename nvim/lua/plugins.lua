require("plugins/mason")
require("plugins/lualine")
require("plugins/fzf")
require("plugins/blink")
require("plugins/tiny_actions")
require("plugins/conform-lua")
require("plugins/ibl")
require("plugins/autopairs")
require("plugins/refactoring-lua")
require("plugins/themes")
require("plugins/nvim-cmp-lua")

-- local deleteUnusedPlugins = function()
-- 	local plg = vim.iter(vim.pack.get())
-- 		:filter(function(x)
-- 			return not x.active
-- 		end)
-- 		:map(function(x)
-- 			return x.spec.name
-- 		end)
-- 		:totable()
-- 	vim.pack.del(plg)
-- end
