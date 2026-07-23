local conditions = require("heirline.conditions")
local utils = require("heirline.utils")
local statusline = require("config.heirline.layouts.statusline")
-- Winbar = the nvim-navic code breadcrumb (icon file › symbol › …). It is shown
-- ONLY on real file editors; disable_winbar_cb below hides it on dashboards,
-- terminals, trees, pickers, etc. so the look stays consistent. Tabline = tabby.
local winbar = require("config.heirline.layouts.winbar")
-- Named palette the components reference (customNormal, winterGreen, lotusWhite4, …).
-- A function (not a table): rebuilt from the ACTIVE colorscheme on every call so
-- the bar tracks whatever theme is loaded. on_colorscheme() below re-invokes it.
local colors = require("config.heirline.components.colors.dynamic")

require("heirline").setup({
	statusline = statusline,
	winbar = winbar,
	opts = {
		colors = colors,
		-- return true → no winbar for that window (keeps special buffers bar-free)
		disable_winbar_cb = function(args)
			return conditions.buffer_matches({
				buftype = { "nofile", "prompt", "help", "quickfix", "terminal" },
				filetype = {
					"neo-tree",
					"neo-tree-popup",
					"alpha",
					"dashboard",
					"Trouble",
					"trouble",
					"toggleterm",
					"TelescopePrompt",
					"lazy",
					"mason",
					"qf",
					"^git.*",
					"fugitive",
				},
			}, args.buf)
		end,
	},
})

-- Heirline compiles its highlights once and does NOT watch 'ColorScheme' on its
-- own, so switching theme (e.g. via <leader>uc) left the statusline on the OLD
-- colors until a restart. on_colorscheme() flushes the highlight cache, reloads
-- the named palette, and drops each window's cache so every component's hl
-- re-resolves against the new theme.
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		utils.on_colorscheme(colors)
	end,
	desc = "heirline: rebuild highlights on colorscheme change",
})

-- Yep, with heirline we're driving manual!
vim.cmd([[au FileType * if index(['wipe', 'delete'], &bufhidden) >= 0 | set nobuflisted | endif]])
