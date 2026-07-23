local pill = require("config.heirline.components.core.pill")

-- Cursor position as a mode-coloured pill mirroring the ViMode pill on the far
-- left:   <line>:<col> · <percent-through-file>
local Position = {
	-- dark ink on the bright mode colour, matching the ViMode pill
	hl = { fg = "sumiInk0", bold = true },

	{
		-- U+E0A1 = powerline "line number" glyph
		provider = " %l:%c ",
	},
	{
		provider = "· %P ",
	},
}

Position = pill(function(self)
	return self:mode_color()
end, Position)

return Position
