-- Filetype with its devicon, tinted to match the icon's language colour.
--   <icon> <filetype>
local FileType = {
	condition = function()
		return vim.bo.filetype ~= ""
	end,

	{ -- coloured language icon
		provider = function()
			local icon = require("nvim-web-devicons").get_icon_by_filetype(vim.bo.filetype, { default = true })
			return icon and (icon .. " ") or ""
		end,
		hl = function()
			local _, color =
				require("nvim-web-devicons").get_icon_color_by_filetype(vim.bo.filetype, { default = true })
			return { fg = color }
		end,
	},
	{ -- filetype label
		provider = function()
			return vim.bo.filetype
		end,
		hl = { fg = "fujiGray", bold = true },
	},
}

return FileType
