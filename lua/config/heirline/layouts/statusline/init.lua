local conditions = require("heirline.conditions")
local colors = require("config.heirline.components.colors.dynamic")

require("heirline").load_colors(colors)

-- layout primitives
local Align = require("config.heirline.components.core.align")
local Space = require("config.heirline.components.core.space")

-- statusline components
local ViMode = require("config.heirline.components.vimode")
local Breadcrumb = require("config.heirline.components.breadcrumb")
local Git = require("config.heirline.components.git")
local Diagnostics = require("config.heirline.components.diagnostics")
local LSPActive = require("config.heirline.components.lsp")
local Position = require("config.heirline.components.position")
local ScrollBar = require("config.heirline.components.core.scrollbar")

-- A dim gap between neighbouring right-side segments.
local Sep = { provider = "   ", hl = { fg = "sumiInk5" } }

return {
	-- Transparent statusline background: the mode/position pills and the scrollbar
	-- carry their own bg, everything else floats over the editor/terminal behind.
	hl = { bg = "NONE" },

	-- ── LEFT: mode pill (logo + name) → file path breadcrumb ──────────────────
	Space,
	ViMode,
	Space,
	Space,
	Breadcrumb,

	Align,

	-- ── RIGHT: diagnostics → lsp → git branch → position pill → scrollbar ─────
	Diagnostics,
	Sep,
	LSPActive,
	Sep,
	Git,
	Space,
	Space,
	Position,
	Space,
	ScrollBar,
	Space,

	static = {
		mode_colors_map = {
			n = "customNormal",
			i = "customInsert",
			v = "customVisual",
			V = "customVisual",
			["\22"] = "customVisual",
			c = "customTerm",
			s = "oniViolet",
			S = "oniViolet",
			["\19"] = "oniViolet",
			R = "customTerm",
			r = "customTerm",
			["!"] = "peachRed",
			t = "customTerm",
			nt = "customTerm", -- terminal-NORMAL mode (mode() returns "nt")
		},
		mode_color = function(self)
			local mode = conditions.is_active() and vim.fn.mode() or "n"
			-- Fall back to the first mode char, then to customNormal, so multi-char
			-- modes (nt, no, niI, cv, …) never return nil — a nil bg would let the
			-- pill fall through to the theme's default StatusLine (blue) highlight.
			return self.mode_colors_map[mode]
				or self.mode_colors_map[mode:sub(1, 1)]
				or "customNormal"
		end,
	},
}
