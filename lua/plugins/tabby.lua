-- Tabline via tabby.nvim (replaces bufferline for the top line). Chosen over
-- bufferline because it can render a fixed HEAD/TAIL widget — bufferline only
-- draws buffers/tabs. Layout mirrors the reference screenshot:
--   [ 󰣇 project ]   [ 1  name ] …tabs… (rounded)            [  branch/local ]
-- Catppuccin-Mocha palette (theme-independent), rounded pill caps, transparent
-- fill so the wallpaper shows between pills (matches the terminal transparency).
return {
	"nanozuki/tabby.nvim",
	event = "VeryLazy",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		vim.o.showtabline = 2 -- always show the tabline

		-- Catppuccin Mocha
		local c = {
			crust = "#11111b",
			surface0 = "#313244",
			text = "#cdd6f4",
			subtext = "#a6adc8",
			blue = "#89b4fa",
			mauve = "#cba6f7",
		}

		local fill = { bg = "NONE" } -- transparent tabline background
		local head = { fg = c.crust, bg = c.blue, style = "bold" } -- project pill
		local current = { fg = c.crust, bg = c.mauve, style = "bold" } -- active tab
		local inactive = { fg = c.subtext, bg = c.surface0 } -- other tabs
		local tail = { fg = c.crust, bg = c.blue, style = "bold" } -- right pill

		-- Rounded pill caps (Nerd Font): left  = U+E0B6, right  = U+E0B4.
		local LEFT, RIGHT = "", ""

		local function project()
			return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
		end

		local function branch()
			local b = vim.b[vim.api.nvim_get_current_buf()].gitsigns_head
			return (b and b ~= "") and b or "local"
		end

		require("tabby").setup({
			line = function(line)
				return {
					-- HEAD: blue rounded project pill
					{
						line.sep(LEFT, head, fill),
						{ " 󰣇 " .. project() .. " ", hl = head },
						line.sep(RIGHT, head, fill),
					},
					-- TABS: rounded pills (active = mauve, others = surface)
					line.tabs().foreach(function(tab)
						local hl = tab.is_current() and current or inactive
						return {
							line.sep(LEFT, hl, fill),
							{ " " .. tab.number() .. "  " .. tab.name() .. " ", hl = hl },
							line.sep(RIGHT, hl, fill),
							margin = " ",
						}
					end),
					line.spacer(),
					-- TAIL: blue rounded pill (git branch, else "local")
					{
						line.sep(LEFT, tail, fill),
						{ "  " .. branch() .. " ", hl = tail },
						line.sep(RIGHT, tail, fill),
					},
					hl = fill,
				}
			end,
		})
	end,
}
