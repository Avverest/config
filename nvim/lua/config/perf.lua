-- Диагностика производительности LSP и автодополнения.
--
-- Ничего не меняет в поведении редактора: только замеряет и показывает.
-- Включается вручную командой :PerfOn, выключается :PerfOff.
-- Смысл разделения: перехват vim.lsp.buf_request держится на обёртке
-- вокруг горячей функции, постоянно он не нужен.

local M = {}

-- ---------------------------------------------------------------------------
-- Хранилище замеров: по методу LSP копим количество, сумму и максимум.
-- Отдельно держим последние N запросов, чтобы видеть не только средние,
-- но и конкретные выбросы — именно они ощущаются как «тормозит».
-- ---------------------------------------------------------------------------
local stats = {}
local recent = {}
local RECENT_MAX = 50
local enabled = false

local function record(client_name, method, ms, extra)
	local key = client_name .. " " .. method
	local s = stats[key]
	if not s then
		s = { n = 0, sum = 0, max = 0, min = math.huge }
		stats[key] = s
	end
	s.n = s.n + 1
	s.sum = s.sum + ms
	s.max = math.max(s.max, ms)
	s.min = math.min(s.min, ms)

	table.insert(recent, {
		ms = ms,
		key = key,
		extra = extra,
		at = os.date("%H:%M:%S"),
	})
	if #recent > RECENT_MAX then
		table.remove(recent, 1)
	end
end

-- ---------------------------------------------------------------------------
-- Перехват запросов клиента. vim.lsp.buf_request — общая точка, через неё
-- уходят и completion, и hover, и diagnostic-запросы от всех модулей,
-- включая mini.completion (он ходит через omnifunc -> buf_request).
-- ---------------------------------------------------------------------------
local orig_buf_request = vim.lsp.buf_request

local function wrapped_buf_request(bufnr, method, params, handler)
	local t0 = vim.uv.hrtime()
	return orig_buf_request(bufnr, method, params, function(err, result, ctx, config)
		local ms = (vim.uv.hrtime() - t0) / 1e6
		local client = vim.lsp.get_client_by_id(ctx and ctx.client_id or 0)
		local name = client and client.name or "?"

		-- для completion интересен размер ответа: именно он объясняет,
		-- почему один и тот же сервер отвечает то за 20, то за 500 мс
		local extra
		if result then
			local items = result.items or (vim.islist(result) and result) or nil
			if items then
				extra = ("%d items"):format(#items)
			end
		end

		record(name, method, ms, extra)
		if handler then
			return handler(err, result, ctx, config)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Замер задержки от нажатия клавиши до появления меню дополнения.
-- Время LSP-запроса — только часть: сверху лежит delay.completion
-- mini.completion, обработка пунктов и отрисовка popup.
-- ---------------------------------------------------------------------------
local typed_at = nil
local menu_group = vim.api.nvim_create_augroup("PerfMenu", { clear = true })

local function setup_menu_tracking()
	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = menu_group,
		callback = function()
			typed_at = vim.uv.hrtime()
		end,
	})

	vim.api.nvim_create_autocmd("CompleteChanged", {
		group = menu_group,
		callback = function()
			if not typed_at then
				return
			end
			local ms = (vim.uv.hrtime() - typed_at) / 1e6
			typed_at = nil
			local info = vim.fn.complete_info({ "items" })
			record("ui", "menu-visible", ms, ("%d items"):format(#(info.items or {})))
		end,
	})
end

-- ---------------------------------------------------------------------------
-- Время выхода серверов на готовность. Работает всегда, а не только при
-- :PerfOn: замер стоит один вызов hrtime на буфер и отвечает на вопрос
-- «почему после открытия файла подсказок ещё нет».
--
-- Считаем от первого открытия буфера данного типа до LspAttach каждого
-- сервера, отдельно — до появления первой диагностики: сервер может
-- прицепиться мгновенно, а проиндексировать проект только через минуту.
-- ---------------------------------------------------------------------------
local attach_times = {}
local buf_opened = {}

vim.api.nvim_create_autocmd("BufReadPre", {
        group = vim.api.nvim_create_augroup("PerfStartup", { clear = true }),
        callback = function(args)
                buf_opened[args.buf] = vim.uv.hrtime()
        end,
})

vim.api.nvim_create_autocmd("LspAttach", {
        group = "PerfStartup",
        callback = function(args)
                local t0 = buf_opened[args.buf]
                if not t0 then
                        return
                end
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                if not client then
                        return
                end
                local ms = (vim.uv.hrtime() - t0) / 1e6
                table.insert(attach_times, {
                        name = client.name,
                        ms = ms,
                        ft = vim.bo[args.buf].filetype,
                        file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(args.buf), ":t"),
                        at = os.date("%H:%M:%S"),
                })
                if #attach_times > 40 then
                        table.remove(attach_times, 1)
                end
        end,
})

-- Первая диагностика от каждого сервера: момент, когда сервер действительно
-- разобрал проект, а не просто ответил на initialize.
local first_diag = {}

vim.api.nvim_create_autocmd("DiagnosticChanged", {
        group = "PerfStartup",
        callback = function(args)
                local t0 = buf_opened[args.buf]
                if not t0 then
                        return
                end
                for _, d in ipairs(args.data and args.data.diagnostics or {}) do
                        local src = d.source or "?"
                        if not first_diag[src] then
                                first_diag[src] = {
                                        ms = (vim.uv.hrtime() - t0) / 1e6,
                                        file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(args.buf), ":t"),
                                }
                        end
                end
        end,
})

-- ---------------------------------------------------------------------------
-- Включение / выключение
-- ---------------------------------------------------------------------------
function M.on()
	if enabled then
		return vim.notify("Профилирование уже включено")
	end
	enabled = true
	vim.lsp.buf_request = wrapped_buf_request
	setup_menu_tracking()
	vim.notify("Профилирование LSP включено. Работайте как обычно, потом :PerfReport")
end

function M.off()
	if not enabled then
		return
	end
	enabled = false
	vim.lsp.buf_request = orig_buf_request
	vim.api.nvim_clear_autocmds({ group = menu_group })
	vim.notify("Профилирование LSP выключено")
end

function M.reset()
	stats = {}
	recent = {}
	vim.notify("Замеры сброшены")
end

-- ---------------------------------------------------------------------------
-- Отчёт
-- ---------------------------------------------------------------------------
function M.report()
	local lines = {}
	local function add(s)
		table.insert(lines, s)
	end

	add("ЗАМЕРЫ LSP")
	add(("состояние: %s"):format(enabled and "включено" or "выключено (:PerfOn)"))
	add("")

	-- сортируем по среднему времени: сверху то, что тормозит систематически
	local rows = {}
	for key, s in pairs(stats) do
		table.insert(rows, { key = key, avg = s.sum / s.n, s = s })
	end
	table.sort(rows, function(a, b)
		return a.avg > b.avg
	end)

	if #rows == 0 then
		add("Данных нет: включите :PerfOn и поработайте в буфере.")
	else
		add(("%-46s %5s %8s %8s %8s"):format("клиент / метод", "N", "сред", "макс", "мин"))
		add(("-"):rep(80))
		for _, r in ipairs(rows) do
			add(("%-46s %5d %7.0fм %7.0fм %7.0fм"):format(
				r.key:sub(1, 46),
				r.s.n,
				r.avg,
				r.s.max,
				r.s.min == math.huge and 0 or r.s.min
			))
		end
	end

	-- выбросы: последние запросы дольше 150 мс — то, что реально заметно глазу
	add("")
	add("ПОСЛЕДНИЕ МЕДЛЕННЫЕ ЗАПРОСЫ (>150 мс)")
	add(("-"):rep(80))
	local slow = 0
	for i = #recent, 1, -1 do
		local r = recent[i]
		if r.ms > 150 then
			slow = slow + 1
			add(("%s %7.0fм  %s%s"):format(
				r.at,
				r.ms,
				r.key,
				r.extra and ("  [" .. r.extra .. "]") or ""
			))
			if slow >= 15 then
				break
			end
		end
	end
	if slow == 0 then
		add("нет — все запросы уложились в 150 мс")
	end

	-- ---------------------------------------------------------------------
	-- Статическая часть: что настроено прямо сейчас. Эти значения
	-- складываются с временем сервера и часто и есть источник «медленно».
	-- ---------------------------------------------------------------------
	add("")
	add("НАСТРОЙКИ, ВЛИЯЮЩИЕ НА ОТЗЫВЧИВОСТЬ")
	add(("-"):rep(80))
	local mc = require("mini.completion").config
	add(("mini.completion delay.completion : %d мс  (пауза до запроса)"):format(mc.delay.completion))
	add(("mini.completion delay.info       : %d мс"):format(mc.delay.info))
	add(("mini.completion delay.signature  : %d мс"):format(mc.delay.signature))
	add(("updatetime                       : %d мс  (CursorHold*)"):format(vim.o.updatetime))
	add(("completeopt                      : %s"):format(vim.o.completeopt))

	-- ---------------------------------------------------------------------
	-- Клиенты на текущем буфере: сколько серверов делят один файл
	-- ---------------------------------------------------------------------
	add("")
	add("ВРЕМЯ ПОДКЛЮЧЕНИЯ СЕРВЕРОВ (от открытия файла до LspAttach)")
	add(("-"):rep(80))
	if #attach_times == 0 then
		add("нет данных — откройте файл проекта в этой сессии")
	end
	for i = #attach_times, math.max(1, #attach_times - 12), -1 do
		local a = attach_times[i]
		add(("%s %-14s %7.0fм  %s (%s)"):format(a.at, a.name, a.ms, a.file, a.ft))
	end

	add("")
	add("ПЕРВАЯ ДИАГНОСТИКА ОТ ИСТОЧНИКА (сервер разобрал проект)")
	add(("-"):rep(80))
	local any_diag = false
	for src, d in pairs(first_diag) do
		any_diag = true
		add(("%-20s %7.0fм  %s"):format(src, d.ms, d.file))
	end
	if not any_diag then
		add("нет данных")
	end

	add("")
	add("КЛИЕНТЫ НА ТЕКУЩЕМ БУФЕРЕ")
	add(("-"):rep(80))
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if #clients == 0 then
		add("нет")
	end
	for _, c in ipairs(clients) do
		local caps = c.server_capabilities or {}
		add(("%-16s root=%s"):format(c.name, c.root_dir or "(нет)"))
		add(("%-16s completion=%s  triggers=%s"):format(
			"",
			caps.completionProvider and "да" or "нет",
			caps.completionProvider
					and table.concat(caps.completionProvider.triggerCharacters or {}, " ")
				or "-"
		))
	end

	-- вывод в отдельном буфере, чтобы можно было листать и копировать
	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "perfreport"
	vim.api.nvim_win_set_height(0, math.min(#lines + 1, 30))
end

vim.api.nvim_create_user_command("PerfOn", M.on, { desc = "Профилирование LSP: включить" })
vim.api.nvim_create_user_command("PerfOff", M.off, { desc = "Профилирование LSP: выключить" })
vim.api.nvim_create_user_command("PerfReset", M.reset, { desc = "Профилирование LSP: сбросить замеры" })
vim.api.nvim_create_user_command("PerfReport", M.report, { desc = "Профилирование LSP: отчёт" })

return M
