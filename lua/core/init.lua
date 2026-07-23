-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Disable unused remote-plugin providers. None of the installed plugins use the
-- Node/Perl/Ruby hosts, so turning them off silences the :checkhealth warnings
-- (python3 is already disabled elsewhere). Clipboard is a separate, real tool —
-- install wl-clipboard for it (see below), don't disable it.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

require("core.bootstrap")
require("core.options")
require("core.keymaps")
require("core.autoreload")
require("core.focus")
