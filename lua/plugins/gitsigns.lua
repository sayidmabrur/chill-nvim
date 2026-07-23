return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		signs = {
			add = { text = "│" },
			change = { text = "│" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
			untracked = { text = "┆" },
		},
		signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
		numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
		linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
		word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
		watch_gitdir = {
			follow_files = true,
		},
		attach_to_untracked = true,
		current_line_blame = true, -- GitLens-style inline blame. Toggle with <leader>gtb
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
			delay = 300,
			ignore_whitespace = false,
		},
		current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
		sign_priority = 6,
		update_debounce = 100,
		max_file_length = 40000, -- Disable if file is longer than this (in lines)
		preview_config = {
			-- Options passed to nvim_open_win
			border = "single",
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},
		on_attach = function(bufnr)
			local gs = package.loaded.gitsigns

			local function map(mode, l, r, map_opts)
				map_opts = map_opts or {}
				map_opts.buffer = bufnr
				vim.keymap.set(mode, l, r, map_opts)
			end

			-- Navigation
			map("n", "]c", function()
				if vim.wo.diff then
					return "]c"
				end
				vim.schedule(function()
					gs.next_hunk()
				end)
				return "<Ignore>"
			end, { expr = true, desc = "Git: next hunk" })

			map("n", "[c", function()
				if vim.wo.diff then
					return "[c"
				end
				vim.schedule(function()
					gs.prev_hunk()
				end)
				return "<Ignore>"
			end, { expr = true, desc = "Git: previous hunk" })

			-- Actions (Hunk submenu: <leader>gh*)
			map("n", "<leader>ghs", gs.stage_hunk, { desc = "Hunk: stage" })
			map("n", "<leader>ghr", gs.reset_hunk, { desc = "Hunk: reset" })
			map("v", "<leader>ghs", function()
				gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, { desc = "Hunk: stage selection" })
			map("v", "<leader>ghr", function()
				gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, { desc = "Hunk: reset selection" })
			map("n", "<leader>ghS", gs.stage_buffer, { desc = "Hunk: stage buffer" })
			map("n", "<leader>ghu", gs.undo_stage_hunk, { desc = "Hunk: undo stage" })
			map("n", "<leader>ghR", gs.reset_buffer, { desc = "Hunk: reset buffer" })
			map("n", "<leader>ghp", gs.preview_hunk, { desc = "Hunk: preview" })
			map("n", "<leader>gB", function()
				gs.blame_line({ full = true })
			end, { desc = "Git: blame line" })
			-- Diff submenu: <leader>gd*
			map("n", "<leader>gdt", gs.diffthis, { desc = "Diff: this (vs index)" })
			map("n", "<leader>gdc", function()
				gs.diffthis("~")
			end, { desc = "Diff: vs last commit" })
			-- Git toggle submenu: <leader>gt*
			map("n", "<leader>gtb", gs.toggle_current_line_blame, { desc = "Git toggle: line blame" })
			map("n", "<leader>gtd", gs.toggle_deleted, { desc = "Git toggle: show deleted" })

			-- Text object
			map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Git: select hunk" })
		end,
	},
}
