vim.api.nvim_create_user_command("Format", function()
	vim.lsp.buf.format()
end, { desc = "Format buffer with LSP" })

-- Buffer-local LSP mappings, set once a server attaches
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		local function map(lhs, rhs, desc)
			vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, silent = true, desc = desc })
		end
		map("K", vim.lsp.buf.hover, "LSP: hover docs")
	end,
})

-- Global diagnostic mappings
-- (]d / [d instead of <C-q>/<C-Q>: in a normal terminal Ctrl+q and Ctrl+Shift+q
--  are the same control code, so the two would collide. ]d/[d also matches the
--  ]c/[c (git) and ]b/[b (buffer) convention already used in this config.)
vim.keymap.set("n", "q", vim.diagnostic.open_float, { silent = true, desc = "Diagnostics: show at cursor" })
vim.keymap.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { silent = true, desc = "Diagnostics: previous" })
vim.keymap.set("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { silent = true, desc = "Diagnostics: next" })
vim.keymap.set("n", "Q", vim.diagnostic.setloclist, { silent = true, desc = "Diagnostics: to loclist" })
