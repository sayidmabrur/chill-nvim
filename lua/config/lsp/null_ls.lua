local null_ls = require("null-ls")

local formatting = null_ls.builtins.formatting
null_ls.setup({
	sources = {
		formatting.stylua,
		formatting.black,
		-- pylama was removed from none-ls builtins; use pyright diagnostics instead
	},
	-- format-on-save is wired via the LspAttach autocmd in config.lsp.handlers
})
