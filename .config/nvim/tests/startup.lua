-- Run from the config directory: nvim --clean -l tests/startup.lua
-- Verify init.lua's complete orchestration without loading plugins or integrations.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local expected = {
  'custom.options', 'custom.keymaps', 'custom.autocmds', 'custom.pack_hooks',
  'custom.plugins.ui', 'custom.plugins.editing', 'custom.plugins.git',
  'custom.plugins.search', 'custom.plugins.lsp', 'custom.plugins.formatting',
  'custom.plugins.markdown', 'custom.plugins.completion', 'custom.plugins.treesitter',
  'custom.plugins.linting', 'custom.plugins.file_explorer', 'custom.integrations.kitty',
  'custom.latex', 'custom.integrations.pi', 'custom.integrations.claude',
}
local calls = {}
for _, name in ipairs(expected) do
  package.loaded[name] = { setup = function() calls[#calls + 1] = name end }
end
assert(loadfile 'init.lua')()
assert(vim.deep_equal(calls, expected), 'Startup sequence changed')
print 'Startup tests passed: all explicit setup calls, core/hooks before plugins, preserved navigation/LSP/LaTeX/integration order'
