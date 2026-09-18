-- Shell terminal: ONE per tab page, reliably reused.
--
-- Why this file exists. Snacks identifies a terminal by a key it builds from
--   vim.inspect({ cmd, cwd, env, count })            -- snacks/terminal.lua M.tid
-- and, for a bare `Snacks.terminal.toggle()`, it fills the last two in itself:
--   cwd   = vim.fn.getcwd(0)   -- the WINDOW-local cwd
--   count = vim.v.count1       -- whatever count you happened to type
-- Both move under you. getcwd(0) follows any :lcd/:tcd and every global :cd (a
-- session restore, an LSP root plugin, a picker that cds), and a stray "2" typed
-- before <C-/> quietly asks for terminal #2. A moved key is a cache MISS, and on
-- a miss Snacks spawns a BRAND-NEW terminal instead of reopening the one you had.
-- That is the "sometimes opens a new terminal" bug.
--
-- So we pin both halves of the key per tab page and cache them in tab-local vars:
-- the cwd is frozen the first time a tab asks for a terminal, and the count is a
-- small serial number the tab owns. The key is then constant for the tab's whole
-- life, so toggling always finds the same terminal -- and a new tab, having a new
-- serial, gets its own.

local M = {}

local next_id = 0

-- Stable (count, cwd) pair for the current tab page.
local function tab_key()
	local tab = vim.api.nvim_get_current_tabpage()
	local id = vim.t[tab].chill_term_id
	if not id then
		next_id = next_id + 1
		id = next_id
		vim.t[tab].chill_term_id = id
	end
	local cwd = vim.t[tab].chill_term_cwd
	if not cwd or cwd == "" or vim.fn.isdirectory(cwd) == 0 then
		-- getcwd(-1, -1) is the GLOBAL cwd, deliberately not the window-local one
		-- Snacks would have used.
		cwd = vim.fn.getcwd(-1, -1)
		vim.t[tab].chill_term_cwd = cwd
	end
	return id, cwd
end

local function term_opts()
	local id, cwd = tab_key()
	return {
		count = id,
		cwd = cwd,
		win = {
			position = "bottom",
			height = 0.3,
			-- keep the split from being squashed when other windows open/close
			wo = { winfixheight = true },
		},
	}
end

-- Windows in THIS tab page showing `buf`.
local function wins_here(buf)
	local out = {}
	if not (buf and vim.api.nvim_buf_is_valid(buf)) then
		return out
	end
	for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_get_buf(w) == buf then
			out[#out + 1] = w
		end
	end
	return out
end

--- Toggle this tab's shell terminal: show it if hidden, hide it if visible.
--- Never creates a second terminal for a tab that already has one.
function M.toggle()
	if not _G.Snacks or not Snacks.terminal then
		vim.notify("snacks.nvim is not loaded yet", vim.log.levels.WARN)
		return
	end

	-- get() opens AND shows on a miss, and tells us so via `created` -- without
	-- that flag we would immediately toggle a freshly opened terminal back off.
	local ok, term, created = pcall(Snacks.terminal.get, nil, term_opts())
	if not ok or not term then
		return
	end
	if created then
		return
	end

	local here = wins_here(term.buf)
	if #here > 0 then
		if vim.api.nvim_get_current_buf() == term.buf then
			vim.cmd("stopinsert")
		end
		term:hide() -- closes term.win, keeps the buffer + job alive
		-- hide() only knows about term.win; close any straggler window in this
		-- tab (a user split, a session-restored window) so one press = one result.
		for _, w in ipairs(here) do
			if vim.api.nvim_win_is_valid(w) and #vim.api.nvim_tabpage_list_wins(0) > 1 then
				pcall(vim.api.nvim_win_close, w, false)
			end
		end
	else
		-- If the window survives in ANOTHER tab, Snacks' show() would consider
		-- itself already visible and draw nothing here. Drop it first.
		if term.win and vim.api.nvim_win_is_valid(term.win) then
			if vim.api.nvim_win_get_tabpage(term.win) ~= vim.api.nvim_get_current_tabpage() then
				pcall(vim.api.nvim_win_close, term.win, false)
				term.win = nil
			end
		end
		term:show()
		if term.win and vim.api.nvim_win_is_valid(term.win) then
			vim.api.nvim_set_current_win(term.win)
			vim.cmd("startinsert")
		end
	end
end

--- Close every shell-terminal WINDOW, in every tab, without killing the jobs.
--- Used before a session is written (see plugins/auto-session.lua) so the saved
--- layout is the code view alone. auto-session's own close_unsupported_windows
--- deliberately spares buftype=="terminal", which is why these outlived a save
--- and came back as dead panes on the next restore.
function M.close_windows()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
			for _, w in ipairs(vim.fn.win_findbuf(buf)) do
				local tab = vim.api.nvim_win_get_tabpage(w)
				if #vim.api.nvim_tabpage_list_wins(tab) > 1 then
					pcall(vim.api.nvim_win_close, w, false)
				end
			end
		end
	end
end

-- A terminal buffer is "dead" once its job channel is gone.
local function job_alive(buf)
	local id = vim.b[buf].terminal_job_id
	if not id then
		return false
	end
	local ok, info = pcall(vim.api.nvim_get_chan_info, id)
	return ok and type(info) == "table" and next(info) ~= nil
end

--- Wipe terminal buffers whose process is already gone.
---
--- A session used to save terminal buffers (see plugins/auto-session.lua), and
--- those come back as corpses: Snacks has no record of them, so they can never
--- be toggled -- they just sit in the buffer list, and the next <C-/> looks like
--- it "opened a new terminal" when it really opened the first live one. Displayed
--- and still-running terminals (including Claude's) are left alone.
function M.sweep_dead()
	local shown = {}
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		shown[vim.api.nvim_win_get_buf(w)] = true
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if
			vim.api.nvim_buf_is_valid(buf)
			and vim.bo[buf].buftype == "terminal"
			and not shown[buf]
			and not job_alive(buf)
		then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
end

vim.api.nvim_create_autocmd("VimEnter", {
	group = vim.api.nvim_create_augroup("ChillTerminalSweep", { clear = true }),
	callback = function()
		-- late enough that auto-session has restored and Claude's auto-resume
		-- (VimEnter + schedule, in plugins/claudecode.lua) has spawned its job.
		vim.defer_fn(M.sweep_dead, 200)
	end,
})

vim.api.nvim_create_user_command("TerminalToggle", M.toggle, { desc = "Toggle this tab's shell terminal" })

return M
