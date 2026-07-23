local icons = require("config.heirline.components.icons")

-- Center breadcrumb for the statusline:  <icon> lua › plugins › neogit.lua ●
local CHEV = " " .. icons.chevron .. " " -- " › "

local FileIcon = {
	init = function(self)
		local filename = vim.api.nvim_buf_get_name(0)
		local ext = vim.fn.fnamemodify(filename, ":e")
		self.icon, self.icon_color =
			require("nvim-web-devicons").get_icon_color(filename, ext, { default = true })
	end,
	provider = function(self)
		return self.icon and (self.icon .. " ") or ""
	end,
	hl = function(self)
		return { fg = self.icon_color }
	end,
}

local Path = {
	provider = function()
		local name = vim.api.nvim_buf_get_name(0)
		if name == "" then
			return "[No Name]"
		end
		-- relative to cwd, split on "/", rejoin with the chevron
		local rel = vim.fn.fnamemodify(name, ":.")
		local parts = vim.split(rel, "/", { plain = true, trimempty = true })
		return table.concat(parts, CHEV)
	end,
	hl = { fg = "fujiWhite", bold = true },
}

local Flags = {
	{
		condition = function()
			return vim.bo.modified
		end,
		provider = function()
			return " " .. icons.modified
		end,
		hl = { fg = "customNormal" },
	},
	{
		condition = function()
			return not vim.bo.modifiable or vim.bo.readonly
		end,
		provider = function()
			return " " .. icons.readonly
		end,
		hl = { fg = "surimiOrange" },
	},
}

return {
	condition = function()
		return vim.api.nvim_buf_get_name(0) ~= ""
	end,
	FileIcon,
	Path,
	Flags,
	{ provider = "%<" }, -- truncate here first when space is tight
}
