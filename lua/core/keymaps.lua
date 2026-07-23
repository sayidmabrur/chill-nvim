--Remap space as leader key
vim.keymap.set("", "<Space>", "<Nop>", { silent = true })
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- every mapping gets a `desc` so which-key.nvim lists it
local function map(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- Normal --
-- Better window navigation
map("n", "<A-h>", "<C-w>h", "Window: go left")
map("n", "<A-j>", "<C-w>j", "Window: go down")
map("n", "<A-k>", "<C-w>k", "Window: go up")
map("n", "<A-l>", "<C-w>l", "Window: go right")

-- Resize with arrows
map("n", "<C-j>", ":resize +2<CR>", "Window: increase height")
map("n", "<C-h>", ":vertical resize +2<CR>", "Window: increase width")
map("n", "<C-l>", ":vertical resize -2<CR>", "Window: decrease width")
map("n", "<C-k>", ":resize -2<CR>", "Window: decrease height")

-- LSP environment / interpreter chooser. Filetype-aware dispatcher so more
-- languages can be added later; for now only Python (pyright) is wired up.
map("n", "<leader>l", function()
	local ft = vim.bo.filetype
	if ft == "python" then
		require("config.lsp.python_env").choose()
	else
		vim.notify("No LSP environment chooser for filetype '" .. ft .. "' yet.", vim.log.levels.INFO)
	end
end, "LSP: choose environment")

-- Buffer cycle (bufferline is disabled in favour of the tabby tabline).
map("n", "]b", ":bnext<cr>", "Buffer: next")
map("n", "[b", ":bprevious<cr>", "Buffer: previous")
-- leader equivalents under the Buffer group
map("n", "<leader>bn", ":bnext<cr>", "Buffer: next")
map("n", "<leader>bN", ":bprevious<cr>", "Buffer: previous")

-- Buffer move: relocate the current buffer's window to a screen edge.
-- Mirrors vim's <C-w> window-move commands: h left, j bottom, k top, l right.
-- The Claude Code terminal is excluded: if it's the focused window the command
-- is a no-op, so buffer-move never drags the Claude session around.
local function buffer_move(dir)
	return function()
		local ok, term = pcall(require, "claudecode.terminal")
		local cbuf = ok and term.get_active_terminal_bufnr and term.get_active_terminal_bufnr() or nil
		if cbuf and vim.api.nvim_get_current_buf() == cbuf then
			vim.notify("Buffer move: ignoring the Claude Code terminal", vim.log.levels.INFO)
			return
		end
		vim.cmd("wincmd " .. dir)
	end
end
map("n", "<leader>bmh", buffer_move("H"), "Buffer move: far left")
map("n", "<leader>bmj", buffer_move("J"), "Buffer move: bottom")
map("n", "<leader>bmk", buffer_move("K"), "Buffer move: top")
map("n", "<leader>bml", buffer_move("L"), "Buffer move: far right")

-- Jumplist back/forward. <C-o> (back) is built-in; pair it with <C-S-o> to jump
-- forward (same as the built-in <C-i>) so you can go back and forth. <C-S-o> is
-- distinct from <C-o> on kitty (kitty keyboard protocol).
map("n", "<C-S-o>", "<C-i>", "Jump: forward (redo jump)")

-- Insert --
-- Press jk fast to enter
map("i", "jk", "<ESC>", "Escape to normal mode")

-- Visual --
-- Stay in indent mode
-- (">" is NOT mapped here: in visual mode Ctrl+Shift+. sends the selection to
--  Claude Code as "path/to/file:10-12" — see lua/plugins/claudecode.lua.
--  To indent, use <Tab>; to dedent, use "<" or <S-Tab>.)
map("v", "<", "<gv", "Dedent selection")
map("v", "<Tab>", ">gv", "Indent selection")
map("v", "<S-Tab>", "<gv", "Dedent selection")

-- Move text up and down
map("v", "<A-j>", ":m .+1<CR>==", "Move line down")
map("v", "<A-k>", ":m .-2<CR>==", "Move line up")
map("v", "p", '"_dP', "Paste without yanking selection")

-- Visual Block --
-- Move text up and down
map("x", "J", ":move '>+1<CR>gv-gv", "Move selection down")
map("x", "K", ":move '<-2<CR>gv-gv", "Move selection up")
map("x", "<A-j>", ":move '>+1<CR>gv-gv", "Move selection down")
map("x", "<A-k>", ":move '<-2<CR>gv-gv", "Move selection up")

-- Terminal --
-- Better terminal navigation
map("t", "<C-h>", "<C-\\><C-N><C-w>h", "Terminal: window left")
map("t", "<C-j>", "<C-\\><C-N><C-w>j", "Terminal: window down")
map("t", "<C-k>", "<C-\\><C-N><C-w>k", "Terminal: window up")
map("t", "<C-l>", "<C-\\><C-N><C-w>l", "Terminal: window right")

-- Buffer Manage
-- (]b/[b live in lua/plugins/bufferline.lua so they cycle in visual bar order)
-- Close the buffer WITHOUT closing its window/split (keeps layout intact),
-- and it disappears from the bufferline. Snacks.bufdelete is resolved at call
-- time, so it's fine that snacks isn't loaded yet when this file runs.
map("n", "<A-w>", function()
	Snacks.bufdelete()
end, "Buffer: close")
map("n", "<leader>bd", function()
	Snacks.bufdelete()
end, "Buffer: close")

-- Tab Manage (<leader>t*)
-- A "tab" is a whole page that can hold several splits/buffers. `:tabclose`
-- closes the entire tab (all its splits) in ONE command, so you never repeat
-- `:q` per split. `gt` / `gT` also cycle tabs.
map("n", "<leader>tn", ":tabnew<cr>", "Tab: new")
map("n", "<leader>tq", function()
	if vim.fn.tabpagenr("$") > 1 then
		vim.cmd("tabclose") -- close current tab and every split inside it
	else
		vim.notify("Last tab — use <leader>qq to quit Neovim", vim.log.levels.INFO)
	end
end, "Tab: close (all its splits at once)")
map("n", "<leader>to", ":tabonly<cr>", "Tab: close all other tabs")
map("n", "<leader>tl", ":tabnext<cr>", "Tab: next")
map("n", "<leader>th", ":tabprevious<cr>", "Tab: previous")

-- Quit / Session (<leader>q*)
map("n", "<leader>qq", ":qa<cr>", "Quit: all")
map("n", "<leader>qw", ":wqa<cr>", "Quit: write all & quit")
map("n", "<leader>qf", ":qa!<cr>", "Quit: force (discard changes)")
