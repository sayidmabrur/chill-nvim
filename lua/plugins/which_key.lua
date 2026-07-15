return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		-- names for the leader-prefix groups shown in the popup
		spec = {
			{ "<leader>a", group = "AI / Claude Code" },
			{ "<leader>b", group = "Buffer" },
			{ "<leader>f", group = "Find (Telescope)" },
			{ "<leader>g", group = "Git (Neogit/Diffview)" },
			{ "<leader>h", group = "Git hunks" },
			{ "<leader>t", group = "Toggle" },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
}
