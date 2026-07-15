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
		vim.o.sessionoptions = "blank,buffers,folds,help,tabpages,winsize,winpos,terminal,localoptions"
	end,

	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
		-- log_level = 'debug',

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
