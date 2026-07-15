local utils = require("heirline.utils")

local conditions = require("heirline.conditions")
local colors = require("config.heirline.components.colors.kanagawa")

require("heirline").load_colors(colors)

-- layout components
local Align = require("config.heirline.components.core.align")
local Space = require("config.heirline.components.core.space")
local block = require("config.heirline.components.core.block")

-- statusline components
local Diagnostics = require("config.heirline.components.diagnostics")
local ViMode = require("config.heirline.components.vimode")
local Ruler = require("config.heirline.components.core.ruler")
local ScrollBar = require("config.heirline.components.core.scrollbar")
local Git = require("config.heirline.components.git")
local FileNameBlock = require("config.heirline.components.filenameblock")
local Circle = { provider = " " }
local LSPActive = require("config.heirline.components.lsp")
local Divider = { provider = "" }

return {
	block,
	Space,
	ViMode,
	Space,
	Space,
	FileNameBlock,
	Align,
	Diagnostics,
	Space,
	Git,
	Space,
	LSPActive,
	Space,
	Space,
	Space,
	-- Divider,
	Space,
	Circle,
	Space,
	Ruler,
	Space,
	ScrollBar,

	static = {
		mode_colors_map = {
			n = "customNormal",
			i = "customInsert",
			v = "customVisual",
			V = "customVisual",
			["\22"] = "customVisual",
			c = "customTerm",
			s = "purple",
			S = "purple",
			["\19"] = "purple",
			R = "customTerm",
			r = "customTerm",
			["!"] = "red",
			t = "customTerm",
		},
		mode_color = function(self)
			local mode = conditions.is_active() and vim.fn.mode() or "n"
			return self.mode_colors_map[mode]
		end,
	},
}
