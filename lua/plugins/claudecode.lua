-- Anchor Claude Code's launch directory to the PROJECT ROOT, not nvim's cwd.
--
-- Without this, the plugin falls back to vim.fn.getcwd() (see claudecode/cwd.lua
-- case #4). auto-session has `curdir` in sessionoptions, so restoring a session
-- silently changes nvim's cwd -- which made Claude open a *different* project's
-- session history. Claude Code buckets sessions by the exact launch dir
-- (~/.claude/projects/<path-with-slashes-as-dashes>), so a wandering cwd = mixed
-- sessions. Pinning to the project root keeps each project's sessions separate.
--
-- Walks up from the current file (or cwd) to the nearest project marker; handles
-- both git repos and non-git projects (e.g. OCR-low-resource has requirements.txt
-- but no .git). Falls back to the ~/projects/<workspace>/<project> folder, then cwd.
-- Pick the directory to resolve the project from. The plugin builds ctx from
-- the FOCUSED buffer (terminal.lua). When that buffer isn't a real file --
-- neo-tree, dashboard, a picker, the Claude terminal itself -- ctx.file_dir is
-- nil and the old code fell back to ctx.cwd == vim.fn.getcwd(). But auto-session
-- keeps `curdir` in sessionoptions, so getcwd() gets silently rewritten to
-- whatever project was last restored => Claude buckets sessions to the WRONG
-- project. So: anchor to an actual open file (focused first, else most-recently
-- used), and only trust getcwd() when no file is open anywhere.
local function anchor_dir(ctx)
	if ctx and ctx.file_dir and ctx.file_dir ~= "" then
		return ctx.file_dir
	end
	local best_buf, best_used = nil, -1
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if
			vim.api.nvim_buf_is_loaded(buf)
			and vim.bo[buf].buftype == ""
			and vim.api.nvim_buf_get_name(buf) ~= ""
		then
			local used = (vim.fn.getbufinfo(buf)[1] or {}).lastused or 0
			if used > best_used then
				best_used, best_buf = used, buf
			end
		end
	end
	if best_buf then
		return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(best_buf), ":h")
	end
	return (ctx and ctx.cwd) or vim.fn.getcwd()
end

local function project_root(ctx)
	local start = anchor_dir(ctx)
	local markers = {
		".git",
		".project-root",
		"requirements.txt",
		"pyproject.toml",
		"setup.py",
		"setup.cfg",
		"package.json",
		"go.mod",
		"Cargo.toml",
		"Makefile",
		"docker-compose.yml",
		"docker-compose.yaml",
	}
	local hit = vim.fs.find(markers, { path = start, upward = true, limit = 1 })[1]
	if hit then
		return vim.fs.dirname(hit)
	end
	-- No marker (e.g. qwen-asr): pin to ~/projects/<workspace>/<project>.
	local home = vim.env.HOME or vim.fn.expand("~")
	local proj = start:match("^" .. vim.pesc(home .. "/projects/") .. "([^/]+/[^/]+)")
	if proj then
		return home .. "/projects/" .. proj
	end
	return start
end

-- :ClaudeCwd -- echo the exact directory Claude would launch in right now, so
-- you can confirm which project's session bucket you'll get WITHOUT digging
-- through ~/.claude/projects/. Builds the same ctx the plugin does (focused
-- buffer's file + dir), then runs it through project_root().
vim.api.nvim_create_user_command("ClaudeCwd", function()
	local file = vim.fn.expand("%:p")
	if file == "" then
		file = nil
	end
	local ctx = {
		file = file,
		file_dir = file and vim.fn.fnamemodify(file, ":h") or nil,
		cwd = vim.fn.getcwd(),
	}
	local root = project_root(ctx)
	vim.notify(
		"Claude launch dir: " .. root .. "\n(nvim getcwd: " .. ctx.cwd .. ")",
		vim.log.levels.INFO,
		{ title = "ClaudeCwd" }
	)
end, { desc = "Show the directory Claude Code would launch in (its session bucket)" })

-- Auto-resume Claude on startup: reopen it right where you left off. Fires only
-- on a bare `nvim` launch (no file/dir args -- the "resume my workspace" case),
-- skips $HOME and /, and stays quiet unless this project already has Claude
-- history -- so it never spawns Claude in a dir you've never used it in.
-- `--continue` picks up the most recent conversation for the launch cwd without
-- a picker. Runs after auto-session finishes (VimEnter + schedule).
--
-- Gated by vim.g.claude_autoresume: ON by default, disable it anywhere before
-- startup (e.g. `vim.g.claude_autoresume = false` in your config, or per-launch
-- `nvim --cmd 'let g:claude_autoresume = 0'`).
if vim.g.claude_autoresume == nil then
	vim.g.claude_autoresume = true
end
vim.api.nvim_create_autocmd("VimEnter", {
	group = vim.api.nvim_create_augroup("ClaudeAutoResume", { clear = true }),
	nested = true,
	callback = function()
		if not vim.g.claude_autoresume or vim.fn.argc() > 0 then
			return
		end
		vim.schedule(function()
			local root = project_root({ cwd = vim.fn.getcwd() })
			local home = vim.env.HOME or vim.fn.expand("~")
			if root == home or root == "/" then
				return
			end
			-- Claude buckets sessions at ~/.claude/projects/<path, / and . -> ->
			local slug = (root:gsub("[/.]", "-"))
			local bucket = home .. "/.claude/projects/" .. slug
			if vim.fn.isdirectory(bucket) == 0 or #vim.fn.glob(bucket .. "/*.jsonl", true, true) == 0 then
				return
			end
			vim.cmd("ClaudeCode --continue")
		end)
	end,
})

-- Sticky Claude terminal across tabs. The plugin keeps ONE Claude session, but
-- its window only lives in the tab it was opened in (its visibility check is
-- global, so switching tabs leaves it behind). This makes the very same terminal
-- follow you: on entering a tab, if Claude is open in another tab, close that
-- window and re-show the same buffer here (no focus steal, no new session). If
-- Claude is hidden everywhere (you toggled it off with <leader>ac), it stays
-- hidden -- we never resurrect it.
vim.api.nvim_create_autocmd("TabEnter", {
	group = vim.api.nvim_create_augroup("ClaudeStickyTab", { clear = true }),
	callback = function()
		vim.schedule(function()
			local ok, term = pcall(require, "claudecode.terminal")
			if not ok or type(term.get_active_terminal_bufnr) ~= "function" then
				return
			end
			local buf = term.get_active_terminal_bufnr()
			if not buf or not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			local cur_tab = vim.api.nvim_get_current_tabpage()
			local here, elsewhere = false, {}
			local info = vim.fn.getbufinfo(buf)[1]
			for _, win in ipairs((info and info.windows) or {}) do
				if vim.api.nvim_win_is_valid(win) then
					if vim.api.nvim_win_get_tabpage(win) == cur_tab then
						here = true
					else
						table.insert(elsewhere, win)
					end
				end
			end
			-- already in this tab, or hidden everywhere (user closed it): leave it.
			if here or #elsewhere == 0 then
				return
			end
			-- open in another tab -> relocate the same terminal into this one.
			for _, win in ipairs(elsewhere) do
				pcall(vim.api.nvim_win_close, win, false)
			end
			pcall(function()
				term.ensure_visible()
			end)
		end)
	end,
})

-- Scroll the Claude chat WITHOUT leaving it. Claude's TUI renders full-screen
-- (alternate screen), so its history is NOT in nvim's terminal-buffer scrollback
-- -- dropping to terminal-normal mode would land in an empty "special mode" with
-- nothing to scroll. Instead we stay in terminal mode and forward a scroll key
-- straight to Claude, whose own viewport scrolls. Requires Claude's fullscreen
-- renderer (PageUp/PageDown bound); toggle it with `/tui fullscreen` inside
-- Claude, or `Ctrl+O` opens a less-style transcript pager as a fallback.
local function claude_send(key)
	return function()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "n", false)
	end
end

-- Clean session switch. `:ClaudeCode --resume/--continue` on an already-open
-- terminal just toggles the window and IGNORES the args (see simple_toggle), and
-- the previous session's Claude process stays connected as a stale WebSocket
-- client. Because <leader>as broadcasts the @-mention to every connected client,
-- a lingering old session steals the selection and the new one gets nothing.
-- So: kill the current Claude terminal first (its process dies -> its client
-- disconnects), then relaunch with the flag so the freshly-picked session is the
-- ONLY connection and selections always land in it.
local function claude_switch(cli_args)
	return function()
		local ok, term = pcall(require, "claudecode.terminal")
		if ok and type(term.get_active_terminal_bufnr) == "function" then
			local buf = term.get_active_terminal_bufnr()
			if buf and vim.api.nvim_buf_is_valid(buf) then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
		end
		-- defer so the provider clears its cached instance (BufWipeout) before we
		-- relaunch; otherwise the reused-terminal path would ignore the flag again.
		vim.defer_fn(function()
			pcall(vim.cmd, "ClaudeCode " .. cli_args)
		end, 150)
	end
end

return {
	"coder/claudecode.nvim",
	dependencies = { "folke/snacks.nvim" },
	-- focus_after_send: after sending a selection/file, move the cursor into
	-- the Claude terminal so you can type a prompt without switching buffers.
	opts = {
		focus_after_send = true,
		-- Reliability when sending a selection (<leader>as) right as a session is
		-- opening. Defaults drop a queued @-mention after 5s (queue_timeout) while
		-- still waiting up to 10s for the connection (connection_timeout) -- so a
		-- slow-to-start session (e.g. --resume/--continue loading a big history)
		-- exceeds 5s, the mention expires, and nothing is written. Give a session
		-- longer to connect, and keep mentions queued for at least that long so they
		-- survive the whole connection window instead of being dropped early.
		connection_timeout = 20000,
		queue_timeout = 20000,
		terminal = {
			-- Launch Claude in the project root so sessions never mix (see above).
			cwd_provider = project_root,
			-- Reliable, single-press way OUT of the Claude terminal back to the
			-- editor. snacks' default is a fiddly double-Esc within 200ms; this
			-- window-scoped key is timing-free and works in every terminal.
			snacks_win_opts = {
				keys = {
					claude_back_to_editor = {
						"<C-w>",
						function()
							vim.cmd("stopinsert")
							vim.cmd("wincmd p")
						end,
						mode = "t",
						desc = "Switch back to editor",
					},
					-- Scroll the chat, focus staying in Claude. <C-k> -> PageUp,
					-- <C-S-k> -> PageDown, sent to the Claude TUI. <C-S-k> is
					-- distinct from <C-k> only under the kitty keyboard protocol
					-- (kitty here) -- and needs kitty_mod+k freed in kitty.conf.
					claude_scroll_up = {
						"<C-k>",
						claude_send("<PageUp>"),
						mode = "t",
						desc = "Claude: scroll up",
					},
					claude_scroll_down = {
						"<C-S-k>",
						claude_send("<PageDown>"),
						mode = "t",
						desc = "Claude: scroll down",
					},
				},
			},
		},
	},
	-- `cmd` lets lazy.nvim create command stubs that load the plugin on first use,
	-- so `:ClaudeCode` and friends work on a fresh start. Without it, a keys-only
	-- spec defers loading until a <leader>a* mapping is pressed and the commands
	-- would not exist yet.
	cmd = {
		"ClaudeCode",
		"ClaudeCodeFocus",
		"ClaudeCodeSelectModel",
		"ClaudeCodeAdd",
		"ClaudeCodeSend",
		"ClaudeCodeTreeAdd",
		"ClaudeCodeStatus",
		"ClaudeCodeStart",
		"ClaudeCodeStop",
		"ClaudeCodeOpen",
		"ClaudeCodeClose",
		"ClaudeCodeDiffAccept",
		"ClaudeCodeDiffDeny",
		"ClaudeCodeCloseAllDiffs",
	},
	keys = {
		{ "<leader>a", nil, desc = "AI/Claude Code" },
		{ "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
		{ "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
		{ "<leader>ar", claude_switch("--resume"), desc = "Resume Claude (clean switch)" },
		{ "<leader>aC", claude_switch("--continue"), desc = "Continue Claude (clean switch)" },
		{ "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
		{ "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
		-- select lines in visual mode, press <leader>as (Space a s): sends
		-- "path/to/file.py:10-12" to Claude and moves focus into the Claude terminal
		{ "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude (file:lines)" },
		{
			"<leader>as",
			"<cmd>ClaudeCodeTreeAdd<cr>",
			desc = "Add file",
			ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw", "snacks_picker_list" },
		},
		-- Diff management
		{ "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
		{ "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
	},
}
