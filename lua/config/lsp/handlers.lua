-- Format on save, for buffers whose attached server can format.
local lsp_formatting = function(bufnr)
	vim.lsp.buf.format({
		filter = function(client)
			-- only use null-ls (stylua/black), never the language servers themselves
			return client.name == "null-ls"
		end,
		bufnr = bufnr,
	})
end

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("LspFormattingAttach", {}),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client:supports_method("textDocument/formatting") then
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = ev.buf })
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = ev.buf,
				callback = function()
					lsp_formatting(ev.buf)
				end,
			})
		end
	end,
})
