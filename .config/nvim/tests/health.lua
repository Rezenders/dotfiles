-- nvim --clean -l tests/health.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local health = require 'custom.health'
local messages, checked = {}, {}
for _, level in ipairs { 'start', 'ok', 'warn', 'error', 'info' } do
  vim.health[level] = function(message) messages[#messages + 1] = level .. ': ' .. message end
end
local function contains(pattern)
  for _, message in ipairs(messages) do
    if message:find(pattern, 1, true) then return true end
  end
  return false
end
local function check(expected)
  messages = {}
  health.check()
  for _, message in ipairs(expected) do
    assert(contains(message), 'Missing health result: ' .. message)
  end
end
vim.fn.executable = function(exe)
  checked[exe] = true
  return exe == 'missing-server' and 0 or 1
end
vim.fn.filereadable = function() return 0 end
vim.fn.isdirectory = function() return 0 end
vim.lsp.config('health_test', { cmd = { 'missing-server' } })
health.lsp_servers = { 'health_test' }
vim.env.KITTY_WINDOW_ID = nil
check { 'missing-server not found', 'Not running inside Kitty', 'Local Pi checkout is missing', 'Pi integration is not loaded' }
for _, exe in ipairs { 'fzf', 'node', 'prettier', 'stylua', 'ruff', 'markdownlint', 'magick', 'kitten', 'latexmk', 'chktex', 'latexindent', 'zathura' } do
  assert(checked[exe], 'Tool not checked: ' .. exe)
end
assert(not checked.go and not checked.dlv, 'Removed debugger tools must not be checked')
vim.env.KITTY_WINDOW_ID = '123'
vim.system = function(args, opts)
  assert(vim.deep_equal(args, { 'kitten', '@', 'ls' }))
  assert(opts.timeout == 2000)
  error 'spawn failed'
end
check { 'Kitty remote control failed:', 'spawn failed' }
vim.system = function()
  return { wait = function() return nil end }
end
check { 'Kitty remote control failed: no result (timeout)' }
vim.system = function()
  return { wait = function() return { code = 124, stderr = 'timeout' } end }
end
check { 'Kitty remote control failed: timeout' }
vim.system = function()
  return { wait = function() return { code = 0, stdout = '[]' } end }
end
vim.fn.isdirectory = function() return 1 end
package.loaded['custom.runtime'] = { pi_ready = true }
check { 'Kitty remote control is reachable', 'Local Pi Lua entrypoint:', 'Pi module loaded' }
print 'health tests passed'
