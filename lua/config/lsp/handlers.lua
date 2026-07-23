-- Attach nvim-navic to any server that can produce a document-symbol tree, so
-- the heirline winbar can show the code breadcrumb. Guarded on the capability
-- (spectral/null-ls don't provide symbols) and silenced for multi-server buffers
-- via vim.g.navic_silence (set in lua/plugins/navic.lua).
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("NavicAttach", {}),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client.server_capabilities.documentSymbolProvider then
			require("nvim-navic").attach(client, ev.buf)
		end
	end,
})

-- Manual formatting only -- NO format-on-save. Run :Format to format the current
-- buffer with null-ls (stylua/black/etc.), never the language servers themselves.
local lsp_formatting = function(bufnr)
	vim.lsp.buf.format({
		filter = function(client)
			return client.name == "null-ls"
		end,
		bufnr = bufnr,
	})
end

vim.api.nvim_create_user_command("Format", function()
	lsp_formatting(vim.api.nvim_get_current_buf())
end, { desc = "Format the current buffer with null-ls (manual; no format-on-save)" })
