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

return {
	"coder/claudecode.nvim",
	dependencies = { "folke/snacks.nvim" },
	-- focus_after_send: after sending a selection/file, move the cursor into
	-- the Claude terminal so you can type a prompt without switching buffers.
	opts = {
		focus_after_send = true,
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
		{ "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
		{ "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
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
