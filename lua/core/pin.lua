-- Pinned sidebars: Neo-tree and the Claude Code terminal look the same in EVERY
-- tab page, so a tab only ever differs in its code view and its shell terminal.
--
-- Neovim has no window that lives outside a tab page -- every window belongs to
-- exactly one tab -- so "pinned" here means REPLICATED: each tab gets its own
-- window onto the SAME buffer (the same Claude session, the same tree). Nothing
-- is moved between tabs, so entering a tab never yanks Claude out of the one you
-- just left (which is what the old ClaudeStickyTab autocmd did, and why the
-- layout shuffled every time you pressed gt).
--
-- The wanted state lives in two globals so it survives tab churn:
--   vim.g.pin_claude, vim.g.pin_neotree
-- A toggle flips the global and applies it to the current tab; every other tab
-- catches up the moment you enter it, including brand-new ones. Leaving a tab
-- re-reads the state off that tab first, so dismissing a sidebar any other way
-- (`q` in the tree, :ClaudeCodeClose, <C-w>c) propagates just the same.
--
-- Claude keeps one extra invariant: the claudecode plugin tracks a single window
-- (`instance.win`) and aims all of its own actions -- focus, hide, "show me after
-- sending a selection" -- at it. Whenever we materialise Claude in a tab we hand
-- that window over as the plugin's window, so those actions always land in the
-- tab you are actually looking at instead of teleporting you to another one.

local M = {}

-- Keep in sync with claudecode's split_width_percentage (its default, 0.30).
local CLAUDE_WIDTH = 0.30

-- ── Small window helpers ────────────────────────────────────────────────────
local function wins_in(tab, pred)
	local out = {}
	if not (tab and vim.api.nvim_tabpage_is_valid(tab)) then
		return out
	end
	for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		if pred(w, vim.api.nvim_win_get_buf(w)) then
			out[#out + 1] = w
		end
	end
	return out
end

local function is_neotree(_, buf)
	return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "neo-tree"
end

-- Dismiss a sidebar window. Closing the LAST window of a tab page takes the tab
-- down with it (the old sticky-tab code closed blind, so a tab holding nothing
-- but Claude vanished when you tabbed away from it), so in that case we empty the
-- window out into a normal scratch buffer instead: the tab survives as a plain
-- editor and the sidebar is still gone, rather than being stuck open forever.
local function close_win(win)
	if not vim.api.nvim_win_is_valid(win) then
		return true
	end
	local tab = vim.api.nvim_win_get_tabpage(win)
	if #vim.api.nvim_tabpage_list_wins(tab) <= 1 then
		return false
	end
	return (pcall(vim.api.nvim_win_close, win, false))
end

local function safe_close(win)
	if close_win(win) or not vim.api.nvim_win_is_valid(win) then
		return
	end

	pcall(function()
		vim.wo[win].winfixbuf = false
	end)
	local scratch = vim.api.nvim_create_buf(true, false)
	if not pcall(vim.api.nvim_win_set_buf, win, scratch) then
		pcall(vim.api.nvim_buf_delete, scratch, { force = true })
		return
	end
	pcall(function()
		vim.wo[win].winfixwidth = false
		vim.wo[win].winfixheight = false
		vim.wo[win].number = vim.o.number
		vim.wo[win].relativenumber = vim.o.relativenumber
		vim.wo[win].signcolumn = vim.o.signcolumn
	end)
end

-- ── Claude Code ─────────────────────────────────────────────────────────────
local function claude_buf()
	local ok, term = pcall(require, "claudecode.terminal")
	if not ok or type(term.get_active_terminal_bufnr) ~= "function" then
		return nil
	end
	local ok2, buf = pcall(term.get_active_terminal_bufnr)
	if ok2 and buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end
	return nil
end

-- The snacks window object claudecode manages, or nil if we cannot reach it.
-- Everything that uses it is guarded, so a plugin update that renames this is a
-- graceful degradation (Claude still pins; the plugin's own keys may target the
-- window in another tab) rather than a broken config.
local function claude_instance()
	local ok, term = pcall(require, "claudecode.terminal")
	if not ok or type(term._get_managed_terminal_for_test) ~= "function" then
		return nil
	end
	local ok2, inst = pcall(term._get_managed_terminal_for_test)
	return ok2 and inst or nil
end

local function claude_wins(tab)
	local buf = claude_buf()
	if not buf then
		return {}
	end
	return wins_in(tab or vim.api.nvim_get_current_tabpage(), function(_, b)
		return b == buf
	end)
end

local function claude_wins_all()
	local buf, out = claude_buf(), {}
	if not buf then
		return out
	end
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(w) == buf then
			out[#out + 1] = w
		end
	end
	return out
end

-- Give this tab a window onto the existing Claude buffer, without stealing focus.
-- `botright <n>vsplit` is the exact geometry claudecode uses when it re-creates
-- its own split, so every tab's copy is the same size and the terminal never
-- reflows (Claude's TUI redraws to the last-sized window) as you switch tabs.
local function claude_show_here(buf)
	local cur = vim.api.nvim_get_current_win()
	local width = math.max(20, math.floor(vim.o.columns * CLAUDE_WIDTH))
	if not pcall(vim.cmd, "noautocmd botright " .. width .. "vsplit") then
		return
	end
	local win = vim.api.nvim_get_current_win()
	-- Attaching the buffer fires BufEnter for it, because `win` is the current
	-- window at this point -- and Snacks binds its auto_insert handler to exactly
	-- that event, so it queues a :startinsert. We are only PLACING the sidebar
	-- here, not entering it, and the pending insert would then land in whatever
	-- window we hand focus back to: you press <leader>ac (or just switch tabs) and
	-- find yourself typing into your source file. Mute BufEnter for this one call.
	-- BufWinEnter is deliberately left alone -- Snacks' fixbuf autocmd needs it.
	local saved_ei = vim.o.eventignore
	vim.opt.eventignore:append("BufEnter")
	local attached = pcall(vim.api.nvim_win_set_buf, win, buf)
	vim.o.eventignore = saved_ei
	if not attached then
		safe_close(win)
		return
	end

	local inst = claude_instance()
	-- Re-apply the window-local options snacks set on its own Claude split (its
	-- "minimal" style: no number column, no sign column, its winhighlight).
	if inst and inst.opts and inst.opts.wo and _G.Snacks and Snacks.util and Snacks.util.wo then
		pcall(Snacks.util.wo, win, inst.opts.wo)
	else
		vim.wo[win].number = false
		vim.wo[win].relativenumber = false
		vim.wo[win].signcolumn = "no"
	end
	vim.wo[win].winfixwidth = true
	-- winfixbuf: nothing (a picker, a quickfix jump, "open file here") may hijack
	-- the sidebar to show a file -- that hijack is what made the layout scramble.
	pcall(function()
		vim.wo[win].winfixbuf = true
	end)

	-- Hand the window to the plugin so ClaudeCodeFocus / focus_after_send / its
	-- own hide all act on THIS tab rather than jumping to where Claude was first
	-- opened.
	if inst then
		inst.win = win
		inst.closed = false
	end

	if vim.api.nvim_win_is_valid(cur) then
		vim.api.nvim_set_current_win(cur)
		-- Belt and braces: never leave the editor in insert mode on our way out.
		if vim.api.nvim_get_current_win() ~= win then
			vim.cmd("stopinsert")
		end
	end
end

-- Put the cursor in a Claude window and start typing, the way the plugin does on
-- a first open. Only ever called from an explicit keypress -- the per-tab sync
-- must stay silent.
local function focus_claude_win(win)
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return false
	end
	vim.api.nvim_set_current_win(win)
	local inst = claude_instance()
	if inst then
		inst.win = win
	end
	if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "terminal" then
		vim.cmd("startinsert")
	end
	return true
end

-- ── Apply the wanted state to one tab ───────────────────────────────────────
local applying = false

function M.apply()
	if applying or vim.v.exiting ~= vim.NIL then
		return
	end
	applying = true
	local tab = vim.api.nvim_get_current_tabpage()
	pcall(function()
		-- OPEN first, CLOSE second. The order matters: dismissing a sidebar that is
		-- the tab's only window cannot simply close it, so doing the opens first
		-- guarantees there is another window to fall back on and the sidebar
		-- actually goes away instead of getting wedged open.

		-- Neo-tree is per-tab by design, so pinning it is just "open it here too".
		if vim.g.pin_neotree and #wins_in(tab, is_neotree) == 0 then
			pcall(vim.cmd, "Neotree show") -- `show` opens without taking focus
		end

		-- Claude is never SPAWNED here: if there is no session yet, entering a tab
		-- must not start one behind your back.
		local buf = claude_buf()
		if buf and vim.g.pin_claude and #claude_wins(tab) == 0 then
			claude_show_here(buf)
		end

		if not vim.g.pin_neotree then
			for _, w in ipairs(wins_in(tab, is_neotree)) do
				safe_close(w)
			end
		end
		if buf and not vim.g.pin_claude then
			for _, w in ipairs(claude_wins(tab)) do
				safe_close(w)
			end
		end
	end)
	applying = false
end

-- ── Toggles ─────────────────────────────────────────────────────────────────
function M.toggle_neotree()
	-- Derive from what is actually on screen, not from the stored flag: if you
	-- closed the tree with `q` from inside it, one <leader>e must bring it back.
	local open = #wins_in(vim.api.nvim_get_current_tabpage(), is_neotree) > 0
	vim.g.pin_neotree = not open
	M.apply()
end

--- @param open? fun() how to launch Claude when no session exists yet.
--- Defaults to a plain :ClaudeCode; plugins/claudecode.lua passes an opener that
--- continues the project's most recent conversation.
function M.toggle_claude(open)
	if #claude_wins() > 0 then
		vim.g.pin_claude = false
		-- Close every copy in every tab, not just this one -- otherwise the other
		-- tabs keep a window on a sidebar you just dismissed.
		for _, w in ipairs(claude_wins_all()) do
			safe_close(w)
		end
		local inst = claude_instance()
		if inst and not (inst.win and vim.api.nvim_win_is_valid(inst.win)) then
			inst.win = nil
		end
		return
	end

	vim.g.pin_claude = true
	if claude_buf() then
		M.apply() -- reuse the running session; never start a second one
		-- <leader>ac means "take me to Claude". The first open focuses it (the
		-- plugin does that itself); re-opening went through M.apply, which places
		-- the sidebar WITHOUT focus because it is also the per-tab sync -- so the
		-- cursor stayed in the code window. Focus it explicitly here instead.
		focus_claude_win(claude_wins()[1])
	elseif open then
		pcall(open) -- first open: let the caller decide how to launch it
	else
		pcall(vim.cmd, "ClaudeCode")
	end
end

-- ClaudeCodeFocus, but tab-local: jump to this tab's copy instead of following
-- the plugin's single tracked window into whatever tab it lives in.
--- @param open? fun() see M.toggle_claude
function M.focus_claude(open)
	local here = claude_wins()
	if #here > 0 then
		if vim.api.nvim_get_current_win() == here[1] then
			M.toggle_claude(open) -- already in it -> dismiss, like the plugin does
			return
		end
		focus_claude_win(here[1])
		return
	end
	M.toggle_claude(open)
end

--- Close the pinned sidebars in EVERY tab, leaving only the code view.
--- Used before a session is written (see plugins/auto-session.lua). Windows only:
--- the Claude buffer and its process are left alone, so a mid-work :SessionSave
--- does not kill the conversation -- it just is not part of what gets saved.
function M.close_sidebars()
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		for _, w in ipairs(wins_in(tab, is_neotree)) do
			close_win(w)
		end
		for _, w in ipairs(claude_wins(tab)) do
			close_win(w)
		end
	end
	vim.g.pin_claude, vim.g.pin_neotree = false, false
end

-- ── Keep every tab in sync ──────────────────────────────────────────────────
-- The wanted state is read back off the tab you LEAVE rather than trusted from
-- the flags alone, so the sidebars follow what you actually did however you did
-- it: `q` inside the tree, :ClaudeCodeClose, <C-w>c, a session that restored with
-- Claude already up. Whatever the last tab looked like is what the next one gets.
local grp = vim.api.nvim_create_augroup("ChillPinnedSidebars", { clear = true })

vim.api.nvim_create_autocmd("TabLeave", {
	group = grp,
	desc = "Remember how the sidebars were arranged in the tab being left",
	callback = function()
		if vim.v.vim_did_enter == 0 or applying then
			return
		end
		local tab = vim.api.nvim_get_current_tabpage()
		vim.g.pin_neotree = #wins_in(tab, is_neotree) > 0
		-- Only when a session exists: claude_switch() deletes the buffer for a
		-- moment while it relaunches, and that gap must not read as "dismissed".
		if claude_buf() then
			vim.g.pin_claude = #claude_wins(tab) > 0
		end
	end,
})

vim.api.nvim_create_autocmd("TabEnter", {
	group = grp,
	desc = "Replicate the pinned Neo-tree / Claude sidebars into this tab",
	callback = function()
		if vim.v.vim_did_enter == 0 then
			return -- startup / session restore is still assembling windows
		end
		vim.schedule(M.apply)
	end,
})

return M
