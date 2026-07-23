-- Tabline via tabby.nvim (replaces bufferline for the top line). Chosen over
-- bufferline because it can render a fixed HEAD/TAIL widget — bufferline only
-- draws buffers/tabs. Layout mirrors the reference screenshot:
--   [ 󰻀 chillin-nvim ]   [ 1  name ] …tabs… (rounded)        [  branch/local ]
--
-- Colors are NOT hardcoded to one theme. The pills reuse the exact same dynamic
-- mode palette the heirline statusline uses (customNormal / customVisual from
-- lua/config/heirline/components/colors/dynamic.lua, itself built from the active
-- colorscheme's highlights), so the tabline matches the NORMAL / TERMINAL / etc.
-- mode indicators. Text/inactive/surface tones are pulled live from the active
-- colorscheme and refreshed on :colorscheme, so switching a theme (:Colors)
-- re-tints the whole tabline to match.
return {
	"nanozuki/tabby.nvim",
	event = "VeryLazy",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		vim.o.showtabline = 2 -- always show the tabline

		-- Shared mode palette BUILDER — the same dynamic palette the statusline
		-- uses (colors/dynamic.lua), rebuilt from the active colorscheme on each
		-- refresh so the tabline pills and the statusline mode pills stay identical.
		local build_palette = require("config.heirline.components.colors.dynamic")

		-- Read a hex color out of a highlight group (nil if unset).
		local function hl(name, key)
			local h = vim.api.nvim_get_hl(0, { name = name, link = false })
			local v = h[key]
			return v and string.format("#%06x", v) or nil
		end

		-- Palette, recomputed from the active colorscheme. Mutated in place so the
		-- `line` closure below always renders with the current theme's tones.
		local P = {}
		local function refresh()
			local mode = build_palette() -- fresh mode colors for the current theme
			-- Dark pill-text ink, straight from the statusline palette (theme bg on
			-- dark schemes, theme fg on light) so tab pills read like the mode pills.
			P.ink = mode.sumiInk0
			P.fg = hl("Comment", "fg") or hl("Normal", "fg") or "#727169" -- inactive tab text
			P.surface = hl("CursorLine", "bg") or hl("Visual", "bg") or "#2a2a37" -- inactive tab bg
			P.normal = mode.customNormal -- matches NORMAL mode pill
			P.visual = mode.customVisual -- matches VISUAL mode pill
		end
		refresh()
		vim.api.nvim_create_autocmd("ColorScheme", { callback = refresh, desc = "tabby: follow colorscheme" })

		-- Rounded pill caps (Nerd Font): left  = U+E0B6, right  = U+E0B4.
		local LEFT, RIGHT = "", ""

		local function branch()
			local b = vim.b[vim.api.nvim_get_current_buf()].gitsigns_head
			return (b and b ~= "") and b or "local"
		end

		require("tabby").setup({
			line = function(line)
				local fill = { bg = "NONE" } -- transparent tabline background
				local head = { fg = P.ink, bg = P.normal, style = "bold" } -- project pill (NORMAL green)
				local current = { fg = P.ink, bg = P.visual, style = "bold" } -- active tab (VISUAL cream)
				local inactive = { fg = P.fg, bg = P.surface } -- other tabs
				local tail = { fg = P.ink, bg = P.normal, style = "bold" } -- right pill (NORMAL green)

				return {
					-- HEAD: green rounded project pill
					{
						line.sep(LEFT, head, fill),
						{ vim.fn.nr2char(0xF0EC0) .. " chillin-nvim ", hl = head },
						line.sep(RIGHT, head, fill),
					},
					-- TABS: rounded pills (active = visual cream, others = surface)
					line.tabs().foreach(function(tab)
						local hlp = tab.is_current() and current or inactive
						return {
							line.sep(LEFT, hlp, fill),
							{ " " .. tab.number() .. "  " .. tab.name() .. " ", hl = hlp },
							line.sep(RIGHT, hlp, fill),
							margin = " ",
						}
					end),
					line.spacer(),
					-- TAIL: green rounded pill (git branch, else "local")
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
