require("core")

require("lazy").setup({ { import = "plugins" } }, {
	ui = {
		wrap = true, -- wrap the lines in the ui
		-- The border to use for the UI window. Accepts same border values as |nvim_open_win()|.
		border = "rounded",
		title = "Made 󰄛 With 󱚦 Love 󰞇 ", ---@type string only works when border is not "none"
	},
})
