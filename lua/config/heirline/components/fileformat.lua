-- OS / line-ending icon for the file: unix , mac , dos .
local FileFormat = {
	static = {
		icons = { unix = "", mac = "", dos = "" },
	},
	provider = function(self)
		return self.icons[vim.bo.fileformat] or vim.bo.fileformat
	end,
	hl = { fg = "fujiGray" },
}

return FileFormat
