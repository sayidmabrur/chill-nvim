-- `nvim <dir>` should actually WORK IN <dir>.
--
-- Neovim does not chdir for a directory argument: it hands the directory to a
-- file explorer and leaves the cwd wherever you launched from. That used to be
-- masked by "curdir" in sessionoptions, which cd'd as a side effect of restoring
-- the session -- but curdir is deliberately off (it made the cwd wander to
-- whatever project was restored last; see plugins/auto-session.lua). Without it,
-- `nvim ~/projects/foo/` launched from ~ leaves the cwd at ~ for the whole
-- session, and everything keyed on the cwd follows it off a cliff:
--
--   * auto-session auto-SAVES under the launch dir on exit. ~ is in
--     suppressed_dirs, so the project's session silently stopped being updated.
--   * Claude Code resolves its launch directory -- and therefore WHICH
--     conversation history it continues -- from the cwd when no file buffer is
--     loaded yet. On VimEnter that races auto-session's restore, so the startup
--     auto-resume resolved ~ , bailed out (it refuses to run in $HOME), and
--     <leader>ac then started a fresh Claude instead of the project's session.
--   * :find, :grep, the shell terminal and every picker start in the wrong tree.
--
-- So do the chdir ourselves, once, before anything reads the cwd: this module is
-- loaded at the very top of lua/core/init.lua, before lazy.setup(), so every
-- plugin's setup and every autocmd sees the right directory. auto-session still
-- finds the session either way -- it looks it up by the directory ARGUMENT --
-- and now the cwd it saves under agrees with the one it restored from.

if vim.fn.argc() == 1 then
	local target = vim.fn.argv(0)
	if type(target) == "string" and target ~= "" and vim.fn.isdirectory(target) == 1 then
		pcall(vim.api.nvim_set_current_dir, vim.fn.fnamemodify(target, ":p"))
	end
end

return {}
