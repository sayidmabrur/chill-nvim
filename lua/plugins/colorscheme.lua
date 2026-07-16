return {
	"folke/tokyonight.nvim",
	lazy = false,
	priority = 1000,
	-- Transparent backgrounds so kitty's window transparency (wallpaper) shows
	-- through Neovim. tokyonight clears Normal/NormalNC and, via styles, the
	-- floating windows and sidebars (neo-tree, etc.).
	opts = {
		transparent = true,
		styles = {
			sidebars = "transparent",
			floats = "transparent",
		},
	},
	config = function(_, opts)
		require("tokyonight").setup(opts)
		local ok = pcall(vim.cmd.colorscheme, "tokyonight-moon")
		if not ok then
			vim.notify("colorscheme tokyonight-moon not found!")
		end
	end,
}
