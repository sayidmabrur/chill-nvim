return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("nvim-treesitter").setup()
		require("nvim-treesitter").install({
			"lua",
			"vim",
			"vimdoc",
			"query",
			"bash",
			"json",
			"yaml",
			"html",
			"css",
			"javascript",
			"typescript",
			"tsx",
			"python",
			"php",
			"markdown",
			"markdown_inline",
		})

		-- the "main" branch of nvim-treesitter dropped the old configs.setup()
		-- API (highlight/indent are no longer auto-wired) — start them per
		-- buffer instead, skipping filetypes with no installed parser.
		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				-- pcall: filetypes without an installed parser (incl. plugin UI
				-- buffers) just keep regex highlighting
				if pcall(vim.treesitter.start, args.buf) then
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end,
		})
	end,
}
