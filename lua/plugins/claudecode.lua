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

-- Does this project already have Claude conversation history? Claude buckets its
-- sessions at ~/.claude/projects/<launch dir with / and . turned into ->, so the
-- bucket for our resolved project root tells us whether `--continue` has anything
-- to continue. Without this check `--continue` errors out in a fresh project.
local function project_has_history()
	local cwd = vim.fn.getcwd()
	-- Resolve from the cwd ITSELF rather than from whatever buffer happens to be
	-- loaded: core/launchdir.lua guarantees the cwd is the directory you launched
	-- in, which is the project we mean, and it is stable from the first moment.
	local root = project_root({ file_dir = cwd, cwd = cwd })
	local home = vim.env.HOME or vim.fn.expand("~")
	if root == home or root == "/" then
		return false
	end
	local bucket = home .. "/.claude/projects/" .. (root:gsub("[/.]", "-"))
	return vim.fn.isdirectory(bucket) == 1 and #vim.fn.glob(bucket .. "/*.jsonl", true, true) > 0
end

-- How <leader>ac opens Claude: pick the project's most recent conversation back
-- up (`--continue`, no picker) when there is one, otherwise start a fresh
-- session. This is where the "resume where I left off" behaviour lives now --
-- ON THE KEYPRESS, not at startup.
local function claude_open()
	vim.cmd(project_has_history() and "ClaudeCode --continue" or "ClaudeCode")
end

-- Startup auto-open: OFF.
--
-- This used to fire on every bare `nvim` in a project with Claude history, so
-- just opening an editor spawned a Claude session you did not ask for. Nothing
-- opens Claude now except you pressing <leader>ac -- which continues the
-- project's conversation anyway, so nothing is lost by not doing it eagerly.
--
-- Flip it back per-launch with `nvim --cmd 'let g:claude_autoresume = 1'`, or
-- permanently by setting vim.g.claude_autoresume = true before this file loads.
if vim.g.claude_autoresume == nil then
	vim.g.claude_autoresume = false
end
vim.api.nvim_create_autocmd("VimEnter", {
	group = vim.api.nvim_create_augroup("ClaudeAutoResume", { clear = true }),
	nested = true,
	callback = function()
		if not vim.g.claude_autoresume or vim.fn.argc() > 0 then
			return
		end
		-- Deferred so auto-session has finished restoring before we resolve the root.
		vim.schedule(function()
			if project_has_history() then
				vim.cmd("ClaudeCode --continue")
			end
		end)
	end,
})

-- Claude is PINNED across tabs -- see lua/core/pin.lua, which owns that now.
--
-- What used to live here was a TabEnter handler that MOVED the single Claude
-- window into whatever tab you entered: it closed the window in the other tab
-- and re-showed the buffer here. Three things went wrong with that.
--   * Claude visibly jumped out of the tab you left, so every gt reshuffled the
--     layout instead of leaving each tab as you had arranged it.
--   * It closed the other tab's window blind. When Claude was the only window in
--     that tab, closing it closed the whole TAB.
--   * It fired on every TabEnter through vim.schedule, so fast tab switching
--     queued several relocations that raced each other.
-- core.pin instead gives each tab its own window onto the same Claude buffer and
-- hands that window to the plugin, so one session shows up identically
-- everywhere and the plugin's own focus/hide still act on the tab you are in.

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
		-- Toggle/focus go through core.pin so they act on EVERY tab's copy: a
		-- toggle-off closes the sidebar everywhere (not just the one window the
		-- plugin tracks), and a focus lands in this tab instead of teleporting you
		-- to the tab Claude was first opened in.
		{ "<leader>ac", function() require("core.pin").toggle_claude(claude_open) end, desc = "Toggle Claude (all tabs)" },
		{ "<leader>af", function() require("core.pin").focus_claude(claude_open) end, desc = "Focus Claude" },
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
