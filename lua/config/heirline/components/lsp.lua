local conditions = require("heirline.conditions")
local icons = require("config.heirline.components.icons")

-- Attached LSP servers with a gears icon.
return {
	condition = conditions.lsp_attached,
	update = { "LspAttach", "LspDetach", "BufEnter" },

	provider = function()
		local names = {}
		for _, server in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
			table.insert(names, server.name)
		end
		if #names == 0 then
			return ""
		end
		return icons.lsp .. " " .. table.concat(names, " ")
	end,
	hl = { fg = "waveAqua2", bold = true },
}
