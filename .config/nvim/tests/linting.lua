-- Run from the config directory: nvim --clean -l tests/linting.lua
-- Preserve the existing event policy without running external linters.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local calls, added = 0, false
local lint = { try_lint = function() calls = calls + 1 end }
package.loaded.lint = lint
---@diagnostic disable-next-line: duplicate-set-field
vim.pack.add = function(plugins)
  assert(vim.deep_equal(plugins, { 'https://github.com/mfussenegger/nvim-lint' }))
  added = true
end
local module = require 'custom.plugins.linting'
module.setup()
assert(added, 'nvim-lint must be registered')
assert(vim.deep_equal(lint.linters_by_ft, { markdown = { 'markdownlint' } }))
-- Reinitialization keeps a single callback per event.
module.setup()
for _, event in ipairs { 'BufEnter', 'BufWritePost', 'InsertLeave' } do
  local handlers = vim.api.nvim_get_autocmds { group = 'lint', event = event }
  assert(#handlers == 1, 'Expected exactly one callback for ' .. event)
  vim.bo.modifiable = true
  local before = calls
  vim.api.nvim_exec_autocmds(event, { group = 'lint', buffer = 0 })
  assert(calls == before + 1, 'Lint event must remain enabled: ' .. event)
  vim.bo.modifiable = false
  vim.api.nvim_exec_autocmds(event, { group = 'lint', buffer = 0 })
  assert(calls == before + 1, 'Non-modifiable buffers must be skipped')
end
vim.bo.modifiable = true
print 'Linting tests passed: Markdown-only linter configuration, unchanged events/modifiable guard, no duplicate handlers'
