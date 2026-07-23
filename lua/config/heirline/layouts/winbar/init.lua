-- Breadcrumb winbar:  <icon> <filename>  <symbol>  <symbol> …
-- The symbol trail comes from nvim-navic (VSCode-style code context). The winbar
-- itself is only drawn on real file editors — the disable_winbar_cb in
-- lua/config/heirline/init.lua hides it on dashboards, terminals, trees, etc.,
-- which keeps the look consistent (like an editor's breadcrumb bar).
local colors = require("config.heirline.components.colors.kanagawa")
require("heirline").load_colors(colors)

-- coloured filetype/devicon for the current file
local FileIcon = {
	init = function(self)
		local filename = vim.api.nvim_buf_get_name(0)
		local extension = vim.fn.fnamemodify(filename, ":e")
		self.icon, self.icon_color =
			require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })
	end,
	provider = function(self)
		return self.icon and (self.icon .. " ") or ""
	end,
	hl = function(self)
		return { fg = self.icon_color }
	end,
}

-- just the file's tail (the crumb trail carries the rest of the context)
local FileName = {
	provider = function()
		local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
		return name ~= "" and name or "[No Name]"
	end,
	hl = { fg = "fujiWhite", bold = true },
}

-- nvim-navic code breadcrumb. `package.loaded` guard so an LSP-less buffer never
-- force-loads navic; once any server attaches (handlers.lua) it becomes available.
local Navic = {
	condition = function()
		return package.loaded["nvim-navic"] and require("nvim-navic").is_available()
	end,
	update = { "CursorMoved", "CursorMovedI", "BufEnter" },
	{
		provider = " " .. vim.fn.nr2char(0x203A) .. " ", -- " › " between file and symbols
		hl = { fg = "fujiGray" },
	},
	{
		-- navic already returns a highlighted, kind-coloured string
		provider = function()
			return require("nvim-navic").get_location()
		end,
	},
}

return {
	hl = { bg = "NONE" }, -- transparent, matches the statusline
	{ provider = " " },
	FileIcon,
	FileName,
	Navic,
	{ provider = "%<" }, -- truncate here when the window is narrow
}
