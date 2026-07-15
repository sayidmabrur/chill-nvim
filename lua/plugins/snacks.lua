return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		bigfile = { enabled = true },
		-- dashboard disabled: alpha-nvim is the start screen (both would open on
		-- launch and conflict). Remove alpha.lua + set enabled = true to switch.
		dashboard = { enabled = false },
		explorer = { enabled = true },
		-- indent disabled: indent-blankline.nvim already draws indent guides
		-- (both on = doubled guides). Remove indent_blankline.lua to switch.
		indent = { enabled = false },
		input = { enabled = true },
		picker = { enabled = true },
		notifier = { enabled = true },
		quickfile = { enabled = true },
		scope = { enabled = true },
		scroll = { enabled = true },
		statuscolumn = { enabled = true },
		words = { enabled = true },
	},
	config = function(_, opts)
		require("snacks").setup(opts)
		-- Ctrl+W inside any snacks terminal returns focus to the editor (leaves
		-- the terminal split open), matching the Claude terminal. Reopen/hide
		-- with <leader>tt or <C-/>.
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "snacks_terminal",
			group = vim.api.nvim_create_augroup("SnacksTerminalBackToEditor", {}),
			callback = function(ev)
				vim.keymap.set("t", "<C-w>", function()
					vim.cmd("stopinsert")
					vim.cmd("wincmd p")
				end, { buffer = ev.buf, desc = "Back to editor" })
			end,
		})
	end,
	keys = {
		-- Terminal: <leader>tt is reliable in every terminal; <C-/> (with its
		-- <C-_> alias that many terminals send for Ctrl+/) is the quick toggle
		-- and also closes it from inside terminal mode.
		{ "<leader>tt", function() Snacks.terminal.toggle() end, desc = "Terminal (toggle)" },
		{ "<C-/>", function() Snacks.terminal.toggle() end, mode = { "n", "t" }, desc = "Terminal (toggle)" },
		{ "<C-_>", function() Snacks.terminal.toggle() end, mode = { "n", "t" }, desc = "which_key_ignore" },
	},
}
