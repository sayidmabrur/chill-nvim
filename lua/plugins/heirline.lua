return {
	"rebelot/heirline.nvim",
	-- Active statusline + winbar. lualine (lua/plugins/lualine.lua) is the disabled
	-- alternative. The palette lives in components/colors/kanagawa.lua (also reused
	-- by tabby.lua for its mode-matched tabline pills).
	event = "UIEnter",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"rebelot/kanagawa.nvim", -- only used for its `.colors` palette module, not as the active colorscheme
	},
	config = function()
		require("config.heirline")
	end,
}
