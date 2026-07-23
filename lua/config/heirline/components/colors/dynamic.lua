-- Dynamic heirline palette.
--
-- Instead of hardcoding kanagawa's hex values, this derives every colour the
-- statusline/winbar reference from the *active* colorscheme's own highlight
-- groups (String → green, DiagnosticError → red, GitSignsAdd → git-add, …), so
-- the bar matches whatever theme is loaded (<leader>uc / :colorscheme).
--
-- It is returned as a FUNCTION so heirline re-invokes it on every theme change:
-- load_colors(), setup{ opts.colors }, and utils.on_colorscheme() all accept a
-- function and evaluate it against the highlights current at call time (the
-- ColorScheme autocmd in ../../init.lua drives the refresh).
--
-- The static kanagawa palette is kept as the fallback for any key a given theme
-- leaves undefined, and its full key set is merged through so nothing that
-- references an un-overridden name can ever resolve to nil.

local fallback = require("config.heirline.components.colors.kanagawa")

-- "#rrggbb" for a highlight group's `attr` (fg/bg), or nil when unset/missing.
-- link = false resolves link chains to their effective colour.
local function hl(group, attr)
	local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
	if not ok or type(h) ~= "table" then
		return nil
	end
	local v = h[attr]
	if type(v) ~= "number" then
		return nil
	end
	return string.format("#%06x", v)
end

-- First group in the list that actually defines `attr`, else `default`.
local function pick(attr, groups, default)
	for _, g in ipairs(groups) do
		local c = hl(g, attr)
		if c then
			return c
		end
	end
	return default
end

-- Linear mix of two "#rrggbb" colours; t = 0 → a, t = 1 → b.
local function blend(a, b, t)
	local function ch(s, i)
		return tonumber(s:sub(i, i + 1), 16)
	end
	local r = ch(a, 2) + (ch(b, 2) - ch(a, 2)) * t
	local g = ch(a, 4) + (ch(b, 4) - ch(a, 4)) * t
	local bl = ch(a, 6) + (ch(b, 6) - ch(a, 6)) * t
	return string.format("#%02x%02x%02x", math.floor(r + 0.5), math.floor(g + 0.5), math.floor(bl + 0.5))
end

-- Perceptual-ish brightness of "#rrggbb" in 0..1 (decides light vs dark theme).
local function luminance(hex)
	local r = tonumber(hex:sub(2, 3), 16) / 255
	local g = tonumber(hex:sub(4, 5), 16) / 255
	local b = tonumber(hex:sub(6, 7), 16) / 255
	return 0.299 * r + 0.587 * g + 0.114 * b
end

return function()
	-- Base surfaces & text, from Normal.
	local bg = pick("bg", { "Normal" }, fallback.sumiInk3)
	local fg = pick("fg", { "Normal" }, fallback.fujiWhite)
	local dark = luminance(bg) < 0.5

	-- Semantic hues, straight from the theme's own syntax / diagnostic groups.
	-- Green is sourced from git-add / added groups first: `String` is an
	-- unreliable green (it is yellow in Dracula, cyan in some themes), whereas a
	-- diff/git "added" colour is green virtually everywhere.
	local green = pick("fg", { "GitSignsAdd", "diffAdded", "Added", "DiagnosticOk", "@string", "String" }, fallback.springGreen)
	local red = pick("fg", { "DiagnosticError", "ErrorMsg", "Error", "diffRemoved" }, fallback.peachRed)
	local yellow = pick("fg", { "DiagnosticWarn", "@type", "Type", "WarningMsg" }, fallback.carpYellow)
	local aqua = pick("fg", { "DiagnosticInfo", "Special", "@function.builtin", "Operator" }, fallback.waveAqua2)
	local violet = pick("fg", { "@keyword", "Keyword", "Statement", "Conditional" }, fallback.oniViolet)
	local orange = pick("fg", { "@number", "Number", "Constant", "@constant" }, fallback.surimiOrange)
	local hint = pick("fg", { "DiagnosticHint", "NonText" }, fallback.lotusWhite5)
	local muted = pick("fg", { "Comment", "LineNr", "NonText" }, fallback.fujiGray)

	-- Ink printed ON the bright mode/position pills: always the dark side so the
	-- pill label stays readable. Dark theme → the theme bg; light theme → the
	-- (dark) theme fg. Both are theme-derived, no magic constant.
	local ink = dark and bg or fg

	return vim.tbl_extend("force", fallback, {
		-- pill ink + dim right-hand separator
		sumiInk0 = ink,
		sumiInk5 = blend(bg, muted, 0.5),

		-- text
		fujiWhite = fg,
		fujiGray = muted,
		lotusWhite4 = fg,

		-- mode-pill colours (semantics preserved: Normal=green, Insert=red,
		-- Visual=yellow, Select=violet, Command/Replace/Term=aqua, Shell=orange)
		customNormal = green,
		customInsert = red,
		customVisual = yellow,
		customTerm = aqua,
		oniViolet = violet,
		peachRed = orange,

		-- git branch + LSP accents
		springGreen = green,
		waveAqua2 = aqua,
		surimiOrange = orange,

		-- git working-tree diff counts
		autumnGreen = pick("fg", { "GitSignsAdd", "diffAdded", "Added" }, green),
		autumnYellow = pick("fg", { "GitSignsChange", "diffChanged", "Changed" }, yellow),
		autumnRed = pick("fg", { "GitSignsDelete", "diffRemoved", "Removed" }, red),

		-- diagnostics (each from the theme's own Diagnostic* group)
		lotusRed4 = red,
		lotusYellow3 = yellow,
		lotusCyan = aqua,
		lotusWhite5 = hint,

		-- scrollbar chip (subtle green-tinted bg + bright fg)
		winterGreen = blend(bg, green, 0.25),
	})
end
