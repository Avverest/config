-- Показываем все отличия от HEAD (включая уже добавленные в индекс).
-- Стандартный Git-источник mini.diff сравнивает только с индексом.
local MiniDiff = require("mini.diff")
local attached = {}
local line_ns = vim.api.nvim_create_namespace("GitDiffLines")

local function refresh(bufnr)
	local state = attached[bufnr]
	if not state then
		return
	end
	state.seq = state.seq + 1
	local seq = state.seq
	vim.system({ "git", "-C", state.root, "show", "HEAD:" .. state.path }, { text = true }, function(result)
		vim.schedule(function()
			if attached[bufnr] ~= state or state.seq ~= seq or not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end
			-- Нет файла в HEAD (новый файл или репозиторий без коммитов).
			MiniDiff.set_ref_text(bufnr, result.code == 0 and result.stdout or "")
		end)
	end)
end

MiniDiff.setup({
	view = { style = "sign", signs = { add = "+", change = "~", delete = "-" } },
	source = {
		name = "HEAD",
		attach = function(bufnr)
			if vim.fn.executable("git") == 0 then
				return false
			end
			local filename = vim.api.nvim_buf_get_name(bufnr)
			local root = vim.fs.root(filename, ".git")
			if not root then
				return false
			end
			attached[bufnr] = { root = root, path = vim.fs.relpath(root, filename), seq = 0 }
			refresh(bufnr)
		end,
		detach = function(bufnr)
			attached[bufnr] = nil
			vim.api.nvim_buf_clear_namespace(bufnr, line_ns, 0, -1)
		end,
	},
	-- Применить hunk к HEAD нельзя; отключаем только staging, навигация остаётся.
	mappings = { apply = "", textobject = "" },
})

-- Подсвечиваем сам текст строк, а не только метки в колонке знаков.
vim.api.nvim_create_autocmd("User", {
	pattern = "MiniDiffUpdated",
	callback = function(args)
		local bufnr = args.buf
		vim.api.nvim_buf_clear_namespace(bufnr, line_ns, 0, -1)
		local data = MiniDiff.get_buf_data(bufnr)
		if not data then
			return
		end
		for _, hunk in ipairs(data.hunks) do
			local group = hunk.type == "add" and "DiffAdd" or "DiffChange"
			for line = hunk.buf_start, hunk.buf_start + hunk.buf_count - 1 do
				vim.api.nvim_buf_set_extmark(bufnr, line_ns, line - 1, 0, { line_hl_group = group })
			end
		end
	end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained" }, {
	callback = function(args)
		refresh(args.buf)
	end,
})
