-- Live-reload buffers that are changed on disk by other programs
-- (e.g. Claude Code editing files while they're open side by side).
-- 'autoread' only reloads when nvim *checks* timestamps, so trigger
-- checks on interaction points and on a short timer.
vim.o.autoread = true

local function checktime()
	-- checktime is not allowed in the cmdline window / cmdline mode
	if vim.fn.getcmdwintype() ~= "" or vim.fn.mode() == "c" then
		return
	end
	vim.cmd("silent! checktime")
end

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermLeave", "TermClose" }, {
	group = vim.api.nvim_create_augroup("AutoReloadCheck", {}),
	callback = checktime,
})

-- timer keeps visible buffers in sync even while focus stays in the
-- Claude Code terminal split
local timer = vim.uv.new_timer()
timer:start(1000, 1000, vim.schedule_wrap(checktime))

vim.api.nvim_create_autocmd("FileChangedShellPost", {
	group = vim.api.nvim_create_augroup("AutoReloadNotify", {}),
	callback = function(args)
		vim.notify("Reloaded " .. vim.fn.fnamemodify(args.file, ":t") .. " (changed on disk)", vim.log.levels.INFO)
	end,
})
