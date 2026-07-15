require("config.lsp.diagnostics")

require("mason").setup()
require("mason-lspconfig").setup({
	ensure_installed = { "lua_ls", "intelephense", "pyright", "ts_ls", "spectral", "html" },
})

require("config.lsp.servers")
require("config.lsp.handlers")
require("config.lsp.keymaps")
