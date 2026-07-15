return {
	"folke/tokyonight.nvim",
	lazy = false,
	priority = 1000,
	opts = {},
	config = function(_, opts)
		require("tokyonight").setup(opts)
		local ok = pcall(vim.cmd.colorscheme, "tokyonight-moon")
		if not ok then
			vim.notify("colorscheme tokyonight-moon not found!")
		end
	end,
}
