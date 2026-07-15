return {
	"rebelot/heirline.nvim",
	event = "UIEnter",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"rebelot/kanagawa.nvim", -- only used for its `.colors` palette module, not as the active colorscheme
	},
	config = function()
		require("config.heirline")
	end,
}
