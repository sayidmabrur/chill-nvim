return {
	"rmagatti/auto-session",
	lazy = false,

	init = function()
		-- "localoptions" makes :mksession save each buffer's filetype, so
		-- restoring a session fires FileType per buffer and lazy-loaded
		-- LSP/treesitter attach normally (recommended by auto-session docs).
		--
		-- "curdir" is intentionally OMITTED: with it, restoring a session :cd's
		-- nvim's global cwd to the session's saved dir, so getcwd() silently
		-- wanders to whatever project was last restored. Claude Code buckets its
		-- session history by launch cwd, so a wandering cwd made a different
		-- project's sessions show up (see claudecode.lua). Without curdir, cwd
		-- stays at nvim's launch dir and each project's sessions stay isolated.
		--
		-- "terminal" is OMITTED too. A restored terminal buffer is a corpse: its
		-- job is gone, and Snacks (which keys terminals in a runtime table that
		-- starts empty) has no record of it, so it can never be toggled -- it just
		-- occupies the buffer list until the next <C-/> appears to "open a new
		-- terminal". Terminals now start fresh each launch; Claude still picks its
		-- conversation back up via the --continue auto-resume in claudecode.lua.
		-- (core.terminal also sweeps any corpses left by sessions saved earlier.)
		vim.o.sessionoptions = "blank,buffers,folds,help,tabpages,winsize,winpos,localoptions"
	end,

	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
		-- log_level = 'debug',

		-- A session records the CODE VIEW and nothing else.
		--
		-- auto-session's own close_unsupported_windows explicitly spares
		-- buftype == "terminal", and it knows nothing about Neo-tree, so a save
		-- captured the shell terminal, the Claude sidebar and the tree as part of
		-- the window layout. On the next restore those came back as dead panes:
		-- terminals with no job (Snacks has no record of them, so they could never
		-- be toggled), and a tree/Claude split that the pinning logic then had to
		-- fight. Close them first and the saved layout is just your files.
		--
		-- Windows only -- buffers and processes are untouched, so running
		-- :SessionSave in the middle of work does not kill the Claude session; the
		-- sidebars simply drop out of the snapshot. Bring them back with
		-- <leader>e / <leader>ac / <C-/>.
		pre_save_cmds = {
			function()
				pcall(function()
					require("core.pin").close_sidebars()
				end)
				pcall(function()
					require("core.terminal").close_windows()
				end)

				-- Drop listed buffers that are not real files on disk. diffview://
				-- entries, Neo-tree's "<name>_hidden_message" placeholders and
				-- friends are recorded as `badd` lines and come back on restore as
				-- buffers that cannot be opened -- this session had 4 of them.
				-- Modified buffers are kept: an unsaved edit is never junk.
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if
						vim.api.nvim_buf_is_valid(buf)
						and vim.bo[buf].buflisted
						and not vim.bo[buf].modified
						and vim.bo[buf].buftype == ""
					then
						local name = vim.api.nvim_buf_get_name(buf)
						if name ~= "" and vim.fn.filereadable(name) == 0 then
							pcall(vim.api.nvim_buf_delete, buf, { force = true })
						end
					end
				end
			end,
		},

		post_restore_cmds = {
			function()
				-- Session restore runs inside an autocmd cycle where did_filetype()
				-- is already set, so nvim's builtin detection (:setf) no-ops and
				-- buffers from sessions saved without "localoptions" come back with
				-- no filetype => no LSP, no treesitter. Re-detect on the next tick,
				-- outside that cycle.
				vim.schedule(function()
					for _, buf in ipairs(vim.api.nvim_list_bufs()) do
						if
							vim.api.nvim_buf_is_loaded(buf)
							and vim.bo[buf].buftype == ""
							and vim.bo[buf].filetype == ""
							and vim.api.nvim_buf_get_name(buf) ~= ""
						then
							vim.api.nvim_buf_call(buf, function()
								vim.cmd("filetype detect")
							end)
						end
					end
				end)
			end,
		},
	},
}
