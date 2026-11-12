-- Run from the config directory: nvim --clean -l tests/diagnostic_list.lua
-- Exercise the actual mapping without loading plugins or language servers.
local source = table.concat(vim.fn.readfile 'lua/custom/keymaps.lua', '\n')
local mapping = assert(source:match("  vim%.keymap%.set%('n', '<leader>q', function%(%)\n.-excluding LTeX%+%)' }%)"))
assert(loadstring(mapping))()
local callback
for _, keymap in ipairs(vim.api.nvim_get_keymap 'n') do
  if keymap.desc == 'Open diagnostic location list (excluding LTeX+)' then callback = keymap.callback end
end
assert(type(callback) == 'function', 'missing diagnostic list mapping')
local buf = vim.api.nvim_get_current_buf()
local namespaces = {
  vim.api.nvim_create_namespace 'nvim.lsp.ltex_plus.101',
  vim.api.nvim_create_namespace 'nvim.lsp.ltex_plus.101.grammar',
  vim.api.nvim_create_namespace 'nvim.lsp.texlab.102',
  vim.api.nvim_create_namespace 'other-provider',
}
for i, ns in ipairs(namespaces) do
  vim.diagnostic.set(ns, buf, {
    { lnum = 0, col = 0, message = 'diagnostic ' .. i, severity = vim.diagnostic.severity.WARN },
  })
end
callback()
local items = vim.fn.getloclist(0)
assert(#items == 2, 'expected only non-LTeX+ diagnostics')
local messages = {}
for _, item in ipairs(items) do messages[item.text] = true end
assert(messages['diagnostic 3'] and messages['diagnostic 4'], 'other providers must remain')
assert(#vim.diagnostic.get(buf) == 4, 'in-buffer diagnostics must remain unchanged')
vim.cmd.lclose()
for _, ns in ipairs(namespaces) do vim.diagnostic.reset(ns, buf) end
callback()
assert(#vim.fn.getloclist(0) == 0, 'empty diagnostics must clear the list')
print 'Diagnostic list regression tests passed'
