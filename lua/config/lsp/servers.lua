-- Native LSP setup (nvim 0.11+ vim.lsp.config API).
-- nvim-lspconfig is still installed: it provides the per-server default configs
-- (cmd/filetypes/root markers) that vim.lsp.config() extends.

-- The nvim-cmp almost supports LSP's capabilities so You should advertise it to LSP servers..
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- applied to every server
vim.lsp.config("*", {
	capabilities = capabilities,
})

-- Lua Language Server
vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			-- Ignore error when accessing vim API
			diagnostics = {
				globals = { "vim" },
			},
		},
	},
})

-- Python: pylsp is auto-enabled by mason-lspconfig, but pyright already
-- handles real diagnostics. Silence pylsp's noisy pycodestyle style checks
-- (E302 "expected 2 blank lines", E501 "line too long", etc.).
vim.lsp.config("pylsp", {
	settings = {
		pylsp = {
			plugins = {
				pycodestyle = { enabled = false },
				mccabe = { enabled = false },
			},
		},
	},
})

vim.lsp.enable({
	"lua_ls", -- Lua
	"intelephense", -- PHP
	"pyright", -- Python
	"ts_ls", -- JavaScript/TypeScript
	"spectral", -- JSON & YAML (OpenAPI linting)
	"html", -- HTML
})
