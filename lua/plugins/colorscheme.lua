-- Colorscheme setup. The plugins below install a set of eye-friendly LIGHT
-- themes (rose-pine-dawn is the default), but `:Colors` / <leader>uc now lists
-- EVERY installed colorscheme (light and dark) so you can pick any of them live.
--
-- Light vs dark is inferred from the scheme name (see is_light + DUAL) so the
-- kitty-opacity fix still fires correctly: light → opaque window (readable),
-- dark → your configured transparency.
--
-- NOTE: the heirline statusline builds its palette dynamically from the ACTIVE
-- colorscheme's highlight groups (lua/config/heirline/components/colors/dynamic.lua,
-- with colors/kanagawa.lua kept as the fallback), so the bar matches whatever
-- scheme you pick. The tabby tabline (lua/plugins/tabby.lua) reuses those same
-- mode colors + follows the active theme, so the pills stay in sync too.

local DEFAULT = "rose-pine-dawn"

-- Schemes that expose BOTH backgrounds under a single `:colorscheme` name
-- (the variant is chosen by 'background'), so list each as two picker entries.
local DUAL = { everforest = true, gruvbox = true }

-- Name fragments that mark a scheme as light (drives 'background' + kitty opacity).
local LIGHT_HINTS = { "light", "dawn", "latte", "lotus", "day", "morning", "shine", "peachpuff" }
local function is_light(name)
	local n = name:lower()
	for _, h in ipairs(LIGHT_HINTS) do
		if n:find(h, 1, true) then
			return true
		end
	end
	return false
end

-- Build picker items from every colorscheme Neovim can see right now.
local function build_items()
	local seen, items = {}, {}
	local function add(name, bg, suffix)
		local key = name .. (suffix or "")
		if seen[key] then
			return
		end
		seen[key] = true
		items[#items + 1] = { name = name, bg = bg, label = name .. (suffix or "") }
	end
	for _, name in ipairs(vim.fn.getcompletion("", "color")) do
		if DUAL[name] then
			add(name, "dark", "  (dark)")
			add(name, "light", "  (light)")
		else
			add(name, is_light(name) and "light" or "dark")
		end
	end
	table.sort(items, function(a, b)
		return a.label < b.label
	end)
	return items
end

-- kitty is configured with `background_opacity 0.4`, which composites the WHOLE
-- window (including a theme's painted background) over the wallpaper. That's fine
-- for a dark theme but murders a light theme's contrast — the cream bg turns muddy
-- and the dark-ish syntax colors wash out. Since kitty here has
-- `allow_remote_control yes` + `dynamic_background_opacity yes`, we make the window
-- opaque while a light theme is active and restore transparency on exit.
-- Set OPAQUE below to e.g. "0.95" if you still want a hint of transparency.
local OPAQUE = "1.0"
local IN_KITTY = vim.env.KITTY_WINDOW_ID ~= nil or (vim.env.TERM or ""):find("kitty") ~= nil

local function kitty_opacity(v)
	if not IN_KITTY then
		return
	end
	pcall(vim.fn.jobstart, { "kitty", "@", "set-background-opacity", v })
end

local function apply(theme)
	vim.o.background = theme.bg or "light"
	local ok, err = pcall(vim.cmd.colorscheme, theme.name)
	if not ok then
		vim.notify("colorscheme " .. theme.name .. " failed:\n" .. tostring(err), vim.log.levels.ERROR)
		return
	end
	-- Light themes need an (near-)opaque window to stay readable.
	kitty_opacity(theme.bg == "light" and OPAQUE or "default")
end

-- Persistence: remember the active colorscheme across restarts. The name +
-- background are written to disk on every ColorScheme change and read back on
-- the next launch. Both are stored because DUAL schemes (everforest/gruvbox)
-- choose their light/dark palette from 'background'.
local persist_file = vim.fn.stdpath("data") .. "/last_colorscheme.json"

local function save_colorscheme()
	local name = vim.g.colors_name
	if not name or name == "" then
		return
	end
	local fd = io.open(persist_file, "w")
	if fd then
		fd:write(vim.json.encode({ name = name, bg = vim.o.background }))
		fd:close()
	end
end

local function read_saved()
	local fd = io.open(persist_file, "r")
	if not fd then
		return nil
	end
	local content = fd:read("*a")
	fd:close()
	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" and data.name then
		return data
	end
	return nil
end

local function scheme_exists(name)
	for _, n in ipairs(vim.fn.getcompletion("", "color")) do
		if n == name then
			return true
		end
	end
	return false
end

-- Registered once (on the rose-pine spec's config) after all theme plugins load.
local function register_picker_and_default()
	vim.api.nvim_create_user_command("Colors", function()
		vim.ui.select(build_items(), {
			prompt = "Colorscheme:",
			format_item = function(t)
				return t.label
			end,
		}, function(choice)
			if choice then
				apply(choice)
			end
		end)
	end, { desc = "Pick a colorscheme" })

	vim.keymap.set("n", "<leader>uc", "<cmd>Colors<cr>", { desc = "UI: pick colorscheme" })

	-- Restore kitty's configured transparency when leaving Neovim.
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			kitty_opacity("default")
		end,
		desc = "Restore kitty background opacity on exit",
	})

	-- Save the choice on every colorscheme change — whether it came from the
	-- <leader>uc / :Colors picker, a raw :colorscheme, or :Telescope colorscheme.
	vim.api.nvim_create_autocmd("ColorScheme", {
		callback = save_colorscheme,
		desc = "Persist the chosen colorscheme",
	})

	-- Restore the last-used colorscheme (or DEFAULT on first run / if the saved
	-- scheme is no longer installed). Deferred to VeryLazy so the lower-priority
	-- theme plugins have finished loading before we try to apply one of them.
	vim.api.nvim_create_autocmd("User", {
		pattern = "VeryLazy",
		desc = "Restore the last-used colorscheme",
		callback = function()
			local saved = read_saved()
			if saved and scheme_exists(saved.name) then
				apply(saved)
			else
				apply({ name = DEFAULT, bg = is_light(DEFAULT) and "light" or "dark" })
			end
		end,
	})
end

return {
	-- Rosé Pine — also hosts the picker + default apply (see config below).
	{
		"rose-pine/neovim",
		name = "rose-pine",
		lazy = false,
		priority = 1000,
		opts = {
			variant = "auto", -- dawn when background=light
			dark_variant = "main",
			styles = { italic = false, transparency = false },
		},
		config = function(_, opts)
			require("rose-pine").setup(opts)
			register_picker_and_default()
		end,
	},

	-- Catppuccin — keep the rich integrations; flavour follows 'background'.
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = false,
		priority = 900,
		opts = {
			flavour = "auto", -- latte when background=light, mocha when dark
			background = { light = "latte", dark = "mocha" },
			transparent_background = false,
			integrations = {
				cmp = true,
				gitsigns = true,
				neotree = true,
				telescope = true,
				treesitter = true,
				which_key = true,
				mason = true,
				indent_blankline = { enabled = true },
				native_lsp = { enabled = true },
			},
		},
		config = function(_, opts)
			require("catppuccin").setup(opts)
		end,
	},

	-- Kanagawa — Lotus is its light variant (also the source of heirline's palette).
	{
		"rebelot/kanagawa.nvim",
		lazy = false,
		priority = 800,
		opts = {
			compile = false,
			background = { light = "lotus", dark = "wave" },
		},
		config = function(_, opts)
			require("kanagawa").setup(opts)
		end,
	},

	-- Everforest — vimscript theme, configured via globals; "soft" = gentlest bg.
	{
		"sainnhe/everforest",
		lazy = false,
		priority = 700,
		config = function()
			vim.g.everforest_background = "soft"
			vim.g.everforest_better_performance = 1
			vim.g.everforest_enable_italic = 0
		end,
	},

	-- Gruvbox — soft contrast keeps the warm background off pure white/black.
	{
		"ellisonleao/gruvbox.nvim",
		lazy = false,
		priority = 600,
		opts = {
			contrast = "soft",
			italic = { strings = false, comments = false, folds = false, operators = false },
		},
		config = function(_, opts)
			require("gruvbox").setup(opts)
		end,
	},

	-- Dracula — maintained Lua port. Colorscheme name: "dracula" (dark).
	{
		"Mofiqul/dracula.nvim",
		name = "dracula",
		lazy = false,
		priority = 500,
		config = function()
			require("dracula").setup({ italic_comment = false })
		end,
	},

	-- Wombat — classic vimscript theme. Colorscheme name: "wombat256mod" (dark).
	{
		"vim-scripts/wombat256.vim",
		lazy = false,
		priority = 400,
	},
}
