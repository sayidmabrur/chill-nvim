-- nvim-navic: VSCode-style code breadcrumbs (file › function › block › …).
-- Populated from the LSP document-symbol tree; attached per-buffer in
-- lua/config/lsp/handlers.lua and rendered by the heirline winbar
-- (lua/config/heirline/layouts/winbar/init.lua).
return {
	"SmiteshP/nvim-navic",
	lazy = true, -- loaded on demand the first time an LSP attaches / the winbar asks
	init = function()
		-- a buffer can have several servers; only one drives navic — don't warn.
		vim.g.navic_silence = true
	end,
	config = function()
		require("nvim-navic").setup({
			separator = " " .. vim.fn.nr2char(0x203A) .. " ", -- " › " between crumbs
			highlight = true, -- colour each crumb by its symbol kind
			depth_limit = 5,
			depth_limit_indicator = "…",
			lsp = { auto_attach = false }, -- we attach manually in handlers.lua
		})
	end,
}
