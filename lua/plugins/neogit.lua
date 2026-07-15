return {
	"NeogitOrg/neogit",
	cmd = "Neogit",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"sindrets/diffview.nvim", -- provides the side-by-side diffs + file list
		"nvim-telescope/telescope.nvim", -- selection UI (already installed)
	},
	keys = {
		{ "<leader>gg", "<cmd>Neogit<cr>", desc = "Git: open Neogit" },
		{ "<leader>gc", "<cmd>Neogit commit<cr>", desc = "Git: commit" },
		{ "<leader>gp", "<cmd>Neogit pull<cr>", desc = "Git: pull" },
		{ "<leader>gP", "<cmd>Neogit push<cr>", desc = "Git: push" },
		{ "<leader>gb", "<cmd>Telescope git_branches<cr>", desc = "Git: branches" },
		-- diffview: see all changed files + diffs, and file history (Diff submenu <leader>gd*)
		{ "<leader>gdd", "<cmd>DiffviewOpen<cr>", desc = "Diff: view (all changes)" },
		{ "<leader>gdf", "<cmd>DiffviewFileHistory %<cr>", desc = "Diff: file history (current)" },
		{ "<leader>gdr", "<cmd>DiffviewFileHistory<cr>", desc = "Diff: repo history" },
	},
	opts = {
		integrations = {
			diffview = true,
			telescope = true,
		},
	},
}
