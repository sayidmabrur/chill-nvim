return {
	"akinsho/bufferline.nvim",
	-- Disabled: the tabline is now tabby.nvim (lua/plugins/tabby.lua), which can
	-- render the fixed project pill bufferline can't. Flip to true to switch back
	-- (and disable tabby) — its buffer-cycle keys move to ]b/[b in core/keymaps.
	enabled = false,
	version = "*",
	event = "VeryLazy",
	dependencies = "nvim-tree/nvim-web-devicons",
	keys = {
		-- cycle in the VISUAL order shown in the bar (plain :bnext/:bprev follow
		-- buffer-number order, which is what looked scrambled before)
		{ "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Buffer: next" },
		{ "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Buffer: previous" },
		-- move the current buffer along the bar
		{ "<leader>bl", "<cmd>BufferLineMoveNext<cr>", desc = "Buffer: move right" },
		{ "<leader>bh", "<cmd>BufferLineMovePrev<cr>", desc = "Buffer: move left" },
		{ "<leader>bp", "<cmd>BufferLinePick<cr>", desc = "Buffer: pick" },
	},
	opts = {
		options = {
			mode = "tabs", -- only show real tab pages, not every open buffer
			numbers = "ordinal", -- 1,2,3 by position (fixes the scrambled numbering)
			close_command = function(n)
				Snacks.bufdelete(n)
			end,
			right_mouse_command = function(n)
				Snacks.bufdelete(n)
			end,
			diagnostics = "nvim_lsp",
			diagnostics_indicator = function(_, _, diag)
				local icons = { error = " ", warning = " " }
				local ret = (diag.error and icons.error .. diag.error .. " " or "")
					.. (diag.warning and icons.warning .. diag.warning or "")
				return vim.trim(ret)
			end,
			show_buffer_close_icons = true,
			show_close_icon = false,
			separator_style = "thin",
			always_show_bufferline = true,
			offsets = {
				{
					filetype = "neo-tree",
					text = "File Explorer",
					highlight = "Directory",
					text_align = "left",
					separator = true,
				},
			},
		},
	},
}
