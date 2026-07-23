-- Central icon table. Every glyph is produced with vim.fn.nr2char(codepoint)
-- rather than a literal character, because literal Nerd-Font glyphs kept getting
-- silently dropped when these files were edited. Codepoints here are all from
-- families proven to render in this setup: Material Design Icons (U+F0000+, e.g.
-- the tabline penguin/arch) and the octicons/Font-Awesome the original config used.
local n = vim.fn.nr2char

return {
	-- vim mode "logos" (keyed by the first char of mode())
	mode = {
		n = n(0x0F0787), -- 󰞇  normal   (same icon the original statusline used)
		i = n(0x0F03EB), -- 󰏫  insert   (pencil)
		v = n(0x0F0208), -- 󰈈  visual   (eye)
		V = n(0x0F0208),
		["\22"] = n(0x0F0208), -- visual-block
		s = n(0x0F03EB), -- select
		S = n(0x0F03EB),
		["\19"] = n(0x0F03EB),
		c = n(0x0F018D), -- 󰆍  command  (console)
		R = n(0x0F0450), -- 󰑐  replace  (refresh)
		r = n(0x0F0450),
		["!"] = n(0x0F120), --   shell    (terminal)
		t = n(0x0F120), --   terminal (terminal)
	},

	git_branch = n(0x0F418), --   (octicon git-branch, from original config)
	lsp = n(0x0F085), --   (gears)

	os = {
		unix = n(0x0F033D), -- 󰌽  linux (penguin — proven to render)
		mac = n(0x0F0035), -- 󰀵  apple
		dos = n(0x0F05B3), -- 󰖳  windows
	},

	modified = n(0x25CF), -- ●  plain Unicode bullet (renders in any font)
	readonly = n(0x0F023), --   lock
	chevron = n(0x203A), -- ›  breadcrumb separator (plain Unicode)
}
