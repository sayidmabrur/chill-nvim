local pill = require("config.heirline.components.core.pill")
local icons = require("config.heirline.components.icons")

local ViMode = {
	-- compute mode once per evaluation and stash it on the instance
	init = function(self)
		self.mode = vim.fn.mode(1) -- :h mode()
	end,

	static = {
		-- verbose-ish names (short forms for the exotic sub-modes)
		mode_names = {
			n = "NORMAL",
			no = "OP",
			nov = "OP",
			noV = "OP",
			["no\22"] = "OP",
			niI = "NORMAL",
			niR = "NORMAL",
			niV = "NORMAL",
			nt = "NORMAL",
			v = "VISUAL",
			vs = "VISUAL",
			V = "V-LINE",
			Vs = "V-LINE",
			["\22"] = "V-BLOCK",
			["\22s"] = "V-BLOCK",
			s = "SELECT",
			S = "S-LINE",
			["\19"] = "S-BLOCK",
			i = "INSERT",
			ic = "INSERT",
			ix = "INSERT",
			R = "REPLACE",
			Rc = "REPLACE",
			Rx = "REPLACE",
			Rv = "V-REPLACE",
			Rvc = "V-REPLACE",
			Rvx = "V-REPLACE",
			c = "COMMAND",
			cv = "EX",
			r = "PROMPT",
			rm = "MORE",
			["r?"] = "CONFIRM",
			["!"] = "SHELL",
			t = "TERMINAL",
		},
		-- one icon per mode family (keyed by the first char of mode()); built via
		-- nr2char in the icons module so the glyphs can't be dropped on edit.
		mode_icons = icons.mode,
	},

	provider = function(self)
		local m = self.mode
		local icon = self.mode_icons[m] or self.mode_icons[m:sub(1, 1)] or ""
		local name = self.mode_names[m] or m
		return string.format(" %s %s ", icon, name)
	end,

	-- dark ink on the bright mode colour, always bold
	hl = { fg = "sumiInk0", bold = true },

	-- redraw the line the instant the mode changes (covers operator-pending too)
	update = {
		"ModeChanged",
		pattern = "*:*",
		callback = vim.schedule_wrap(function()
			vim.cmd("redrawstatus")
		end),
	},
}

-- rounded pill tinted with the current mode colour (resolved up the ancestor
-- chain from the statusline's `mode_color` helper)
ViMode = pill(function(self)
	return self:mode_color()
end, ViMode)

return ViMode
