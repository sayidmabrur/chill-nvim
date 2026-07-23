return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		-- names for the leader-prefix groups shown in the popup.
		-- Scheme: <leader> picks a SUBJECT, the next key picks the ACTION.
		spec = {
			{ "<leader>a", group = "AI / Claude Code" },
			{ "<leader>b", group = "Buffer" },
			{ "<leader>bm", group = "Buffer move" },
			{ "<leader>e", desc = "Explorer (Neo-tree)" },
			{ "<leader>f", group = "Find (Telescope)" },
			{ "<leader>g", group = "Git" },
			{ "<leader>l", desc = "LSP env (choose interpreter)" },
			{ "<leader>gd", group = "Diff" },
			{ "<leader>gh", group = "Hunk" },
			{ "<leader>gt", group = "Git toggle" },
			{ "<leader>m", group = "Multicursor" },
			{ "<leader>q", group = "Quit / Session" },
			{ "<leader>t", group = "Tab" },
			{ "<leader>u", group = "UI / Toggle" },
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
