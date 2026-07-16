-- Focus mode: a Pomodoro-style work/break cadence for long sessions.
--   • :FocusMode 60  → focus for 60 min, then a fullscreen break screen appears.
--   • The break screen (milli anime, like the screensaver) asks how long to rest:
--     press 2 or 5 for a 2/5-min break, or Esc to skip. Then focus resumes (repeats).
--   • A small floating widget shows focus progress + how long this nvim session
--     has been running.
-- Pure nvim + milli (optional). Everything is guarded/pcall'd and cleaned up on
-- exit so it can't wedge the UI. Commands: :FocusMode [min], :FocusUptime, :FocusBreak.

local M = {}
local uv = vim.uv or vim.loop

-- ── Config (tweak to taste) ──────────────────────────────────────────────────
local DEFAULT_WORK_MIN = 60 -- :FocusMode with no number uses this
local BREAK_CHOICES = { 2, 5 } -- break lengths offered on the prompt (minutes)
local WINBLEND = 10 -- break-screen transparency (0 opaque … 100 clear)
local AUTO_START = false -- true = start focus mode automatically on launch
local SPLASH_FALLBACK = "vibecat" -- break-screen art if no baked splash_hero

-- ── State ────────────────────────────────────────────────────────────────────
local session_start = os.time() -- nvim launch (module loads at startup)
local enabled = false
local work_min = DEFAULT_WORK_MIN
local work_start -- os.time the current focus block began
local work_timer = assert(uv.new_timer())
local break_timer = assert(uv.new_timer())
local uptime_timer = assert(uv.new_timer())
local break_win, break_buf, break_phase, break_end, art_row, status_row
local uptime_win, uptime_buf
local schedule_work, end_break -- forward decls

local msg_ns = vim.api.nvim_create_namespace("focus_break_msg")
local status_ns = vim.api.nvim_create_namespace("focus_break_status")

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function valid_win(w)
	return w and vim.api.nvim_win_is_valid(w)
end
local function valid_buf(b)
	return b and vim.api.nvim_buf_is_valid(b)
end
local function center(line, width)
	local w = vim.fn.strdisplaywidth(line)
	return string.rep(" ", math.max(0, math.floor((width - w) / 2))) .. line
end

local function fmt_uptime(sec)
	local m = math.floor(sec / 60)
	local h = math.floor(m / 60)
	m = m % 60
	return h > 0 and string.format("%dh%02dm", h, m) or string.format("%dm", m)
end

-- "60" → "1 hour", "120" → "2 hours", "90" → "1h30m", "45" → "45 minutes"
local function human_min(min)
	if min >= 60 then
		local h, m = math.floor(min / 60), min % 60
		if m == 0 then
			return h .. (h == 1 and " hour" or " hours")
		end
		return string.format("%dh%02dm", h, m)
	end
	return min .. " minutes"
end

-- Baked anime if present, else the bundled fallback (mirrors milli.lua's choice).
local function splash_name()
	local hero = vim.fn.stdpath("config") .. "/lua/milli/splashes/splash_hero.lua"
	return uv.fs_stat(hero) and "splash_hero" or SPLASH_FALLBACK
end

-- ── Uptime / focus-progress widget (small float, top-right) ──────────────────
local function widget_text()
	local up = fmt_uptime(os.time() - session_start)
	if not enabled then
		return "  🧘 active " .. up .. "  "
	end
	if valid_win(break_win) then
		return "  ☕ on break · up " .. up .. "  "
	end
	local emin = math.floor((os.time() - (work_start or os.time())) / 60)
	return string.format("  🧘 focus %d/%dm · up %s  ", emin, work_min, up)
end

local function draw_uptime()
	if not valid_buf(uptime_buf) then
		return
	end
	local text = widget_text()
	vim.bo[uptime_buf].modifiable = true
	pcall(vim.api.nvim_buf_set_lines, uptime_buf, 0, -1, false, { text })
	vim.bo[uptime_buf].modifiable = false
	if valid_win(uptime_win) then
		pcall(vim.api.nvim_win_set_config, uptime_win, {
			relative = "editor",
			anchor = "NE",
			row = 0,
			col = vim.o.columns,
			width = vim.fn.strdisplaywidth(text),
			height = 1,
		})
	end
end

local function open_uptime()
	if valid_win(uptime_win) then
		return
	end
	uptime_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[uptime_buf].bufhidden = "wipe"
	local text = widget_text()
	uptime_win = vim.api.nvim_open_win(uptime_buf, false, {
		relative = "editor",
		anchor = "NE",
		row = 0,
		col = vim.o.columns,
		width = vim.fn.strdisplaywidth(text),
		height = 1,
		style = "minimal",
		focusable = false,
		noautocmd = true,
		zindex = 50,
	})
	vim.wo[uptime_win].winhighlight = "Normal:Comment"
	draw_uptime()
end

local function close_uptime()
	if valid_win(uptime_win) then
		pcall(vim.api.nvim_win_close, uptime_win, true)
	end
	if valid_buf(uptime_buf) then
		pcall(vim.api.nvim_buf_delete, uptime_buf, { force = true })
	end
	uptime_win, uptime_buf = nil, nil
end

-- ── Break screen ─────────────────────────────────────────────────────────────
local function break_message()
	return {
		"go stretching and rest 🧘",
		"you've been here for " .. human_min(work_min) .. ".",
		"look far away, breathe, drink some water. 💧",
	}
end

-- Seed the buffer once: milli art (top) + message + a status line. milli animates
-- only the art rows, so the message/status rows below it are never overwritten.
local function build_break()
	local W = vim.o.columns
	local H = math.max(1, vim.o.lines - vim.o.cmdheight)
	local msg = break_message()
	local GAP = 2

	-- Try to load splash art (optional — degrade to text if milli/data absent).
	local frame, cols, milli
	do
		local ok, mod = pcall(require, "milli")
		if ok then
			milli = mod
			local ok2, data = pcall(mod.load, { splash = splash_name() })
			if ok2 and data and data.frames and data.frames[1] then
				frame = data.frames[1]
				cols = data.cols or 0
				if cols == 0 then
					for _, l in ipairs(frame) do
						cols = math.max(cols, vim.fn.strdisplaywidth(l))
					end
				end
			end
		end
	end

	local art_h = frame and #frame or 0
	local art_gap = frame and GAP or 0
	local total = art_h + art_gap + #msg + GAP + 1
	local top = math.max(0, math.floor((H - total) / 2))

	local lines = {}
	for _ = 1, top do
		lines[#lines + 1] = ""
	end
	if frame then
		art_row = #lines
		local pad = string.rep(" ", math.max(0, math.floor((W - cols) / 2)))
		for _, l in ipairs(frame) do
			lines[#lines + 1] = pad .. l
		end
		for _ = 1, GAP do
			lines[#lines + 1] = ""
		end
	else
		art_row = nil
	end
	local msg_row = #lines
	for _, l in ipairs(msg) do
		lines[#lines + 1] = center(l, W)
	end
	for _ = 1, GAP do
		lines[#lines + 1] = ""
	end
	status_row = #lines
	lines[#lines + 1] = "" -- filled by draw_status()

	vim.bo[break_buf].modifiable = true
	pcall(vim.api.nvim_buf_set_lines, break_buf, 0, -1, false, lines)
	vim.bo[break_buf].modifiable = false

	vim.api.nvim_buf_clear_namespace(break_buf, msg_ns, 0, -1)
	for i in ipairs(msg) do
		pcall(vim.api.nvim_buf_set_extmark, break_buf, msg_ns, msg_row + i - 1, 0, {
			end_col = #lines[msg_row + i],
			hl_group = "Comment",
		})
	end

	-- Animate the art (after seeding, so milli's anchor search finds frame 0).
	if frame and milli then
		pcall(milli.play, break_buf, { splash = splash_name(), loop = true })
	end
end

local function draw_status()
	if not valid_buf(break_buf) or not status_row then
		return
	end
	local text
	if break_phase == "prompt" then
		local opts = {}
		for _, m in ipairs(BREAK_CHOICES) do
			opts[#opts + 1] = string.format("[%d] %d-min", m, m)
		end
		text = "take a break?    " .. table.concat(opts, "     ") .. "     [Esc] keep working"
	else
		local remain = math.max(0, break_end - os.time())
		text = string.format("resuming in %d:%02d       q / Esc to skip", math.floor(remain / 60), remain % 60)
	end
	local line = center(text, vim.o.columns)
	vim.bo[break_buf].modifiable = true
	pcall(vim.api.nvim_buf_set_lines, break_buf, status_row, status_row + 1, false, { line })
	vim.bo[break_buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(break_buf, status_ns, status_row, status_row + 1)
	pcall(vim.api.nvim_buf_set_extmark, break_buf, status_ns, status_row, 0, { end_col = #line, hl_group = "Title" })
end

end_break = function()
	break_timer:stop()
	if valid_win(break_win) then
		pcall(vim.api.nvim_win_close, break_win, true)
	end
	if valid_buf(break_buf) then
		pcall(vim.api.nvim_buf_delete, break_buf, { force = true })
	end
	break_win, break_buf, break_phase, break_end, art_row, status_row = nil, nil, nil, nil, nil, nil
	vim.g.focus_break_active = false -- let the idle screensaver run again
	if enabled then
		schedule_work() -- start the next focus block
	end
end

local function begin_break(mins)
	if break_phase ~= "prompt" then
		return
	end
	break_phase = "counting"
	break_end = os.time() + mins * 60
	draw_status()
	break_timer:stop()
	break_timer:start(1000, 1000, vim.schedule_wrap(function()
		if os.time() >= break_end then
			end_break()
		else
			draw_status()
		end
	end))
end

local function start_break()
	if valid_win(break_win) then
		return
	end
	vim.g.focus_break_active = true -- suppress the idle screensaver during the break
	break_phase = "prompt"
	break_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[break_buf].bufhidden = "wipe"
	local ok = pcall(function()
		break_win = vim.api.nvim_open_win(break_buf, true, {
			relative = "editor",
			width = vim.o.columns,
			height = math.max(1, vim.o.lines - vim.o.cmdheight),
			row = 0,
			col = 0,
			style = "minimal",
			focusable = true,
			zindex = 400,
		})
		vim.api.nvim_set_hl(0, "FocusBreakBg", { bg = "none" })
		vim.wo[break_win].winhighlight = "Normal:FocusBreakBg,NormalFloat:FocusBreakBg"
		vim.wo[break_win].winblend = WINBLEND

		local function mapb(lhs, fn)
			vim.keymap.set("n", lhs, fn, { buffer = break_buf, nowait = true, silent = true })
		end
		for _, m in ipairs(BREAK_CHOICES) do
			mapb(tostring(m), function()
				begin_break(m)
			end)
		end
		mapb("q", end_break)
		mapb("<Esc>", end_break)

		build_break()
		draw_status()
	end)
	if not ok then
		end_break()
	end
end

-- ── Work timer ───────────────────────────────────────────────────────────────
schedule_work = function()
	work_start = os.time()
	work_timer:stop()
	work_timer:start(work_min * 60 * 1000, 0, vim.schedule_wrap(start_break))
end

-- ── Public API ───────────────────────────────────────────────────────────────
function M.enable(min)
	work_min = (min and min > 0) and math.floor(min) or DEFAULT_WORK_MIN
	if not enabled then
		enabled = true
		open_uptime()
		uptime_timer:start(0, 15000, vim.schedule_wrap(draw_uptime))
	end
	schedule_work() -- (re)start the focus block with the current length
	vim.notify(string.format("focus mode ON — %s focus, then a break", human_min(work_min)), vim.log.levels.INFO)
end

function M.disable()
	if not enabled then
		return
	end
	enabled = false
	work_timer:stop()
	uptime_timer:stop()
	end_break()
	close_uptime()
	vim.notify("focus mode OFF", vim.log.levels.INFO)
end

function M.toggle(min)
	if enabled and not min then
		M.disable()
	else
		M.enable(min)
	end
end

function M.toggle_uptime()
	if valid_win(uptime_win) then
		close_uptime()
	else
		open_uptime()
		if not enabled then
			uptime_timer:start(0, 15000, vim.schedule_wrap(draw_uptime))
		end
	end
end

-- :FocusMode        → toggle (default length)
-- :FocusMode 90     → start/restart a 90-min focus block
-- :FocusMode off    → stop
vim.api.nvim_create_user_command("FocusMode", function(o)
	local a = vim.trim(o.args)
	if a == "off" or a == "stop" or a == "0" then
		M.disable()
	elseif a == "" then
		M.toggle()
	else
		local n = tonumber(a)
		if not n or n <= 0 then
			vim.notify("FocusMode: give minutes, e.g. :FocusMode 60  (or 'off')", vim.log.levels.WARN)
			return
		end
		M.enable(n)
	end
end, {
	nargs = "?",
	complete = function()
		return { "60", "90", "120", "off" }
	end,
	desc = "Focus mode: :FocusMode [minutes|off] (Pomodoro work/break cycle)",
})

vim.api.nvim_create_user_command("FocusUptime", M.toggle_uptime, { desc = "Toggle the session-uptime floating widget" })
vim.api.nvim_create_user_command("FocusBreak", start_break, { desc = "Show the break screen now (manual / preview)" })

-- UI toggle group: <leader>uf toggles focus mode (next to <leader>ut terminal)
vim.keymap.set("n", "<leader>uf", function()
	M.toggle()
end, { silent = true, desc = "Focus mode (Pomodoro work/break + uptime)" })

-- Reposition the widget on resize; clean up all timers on exit.
local grp = vim.api.nvim_create_augroup("FocusMode", { clear = true })
vim.api.nvim_create_autocmd("VimResized", {
	group = grp,
	callback = function()
		if valid_win(uptime_win) then
			draw_uptime()
		end
	end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
	group = grp,
	callback = function()
		pcall(function()
			work_timer:stop()
			break_timer:stop()
			uptime_timer:stop()
		end)
	end,
})

if AUTO_START then
	vim.schedule(function()
		M.enable()
	end)
end

return M
