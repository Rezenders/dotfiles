-- Run from the config directory: nvim --clean -l tests/lsp_tools.lua
-- Verify formatter tool installation without enabling real servers or installing packages.
---@diagnostic disable: duplicate-set-field
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.pack.add = function() end
local configs, enabled, installed = {}, {}, nil
package.loaded.fidget = { setup = function() end }
package.loaded.mason = { setup = function() end }
package.loaded['mason-lspconfig'] = { setup = function() end }
package.loaded['mason-tool-installer'] = { setup = function(options) installed = options.ensure_installed end }
package.loaded['blink.cmp'] = { get_lsp_capabilities = function() return {} end }
package.loaded['custom.latex.lsp'] = { servers = function() return { texlab = {}, ltex_plus = {} } end }
vim.lsp.config = function(name, config) configs[name] = config end
vim.lsp.enable = function(name) enabled[name] = true end
require('custom.plugins.lsp').setup()
assert(not configs.stylua and not enabled.stylua, 'StyLua must not run as a language server')
for _, name in ipairs { 'stylua', 'ruff', 'prettier', 'markdownlint' } do
  assert(vim.list_contains(installed, name), 'Mason must retain the required tool: ' .. name)
end
assert(configs.lua_ls.settings.Lua.format.enable == false)
assert(enabled.lua_ls and enabled.pyright and enabled.ruff and enabled.texlab)
assert(not vim.list_contains(require('custom.health').lsp_servers, 'stylua'), 'Health must only list actual servers')
print 'LSP tool tests passed: StyLua remains installed but is no longer a server; Lua/Python/LaTeX language features retained'
