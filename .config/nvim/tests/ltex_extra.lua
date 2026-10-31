-- Run from the config directory: nvim --clean -l tests/ltex_extra.lua
local config = vim.fn.getcwd()
vim.opt.runtimepath:prepend(config)
local plugin = vim.fn.glob(vim.fn.stdpath('data') .. '/site/pack/*/opt/ltex_extra.nvim', false, true)[1]
assert(plugin, 'ltex_extra.nvim must be installed to run this regression test')
vim.opt.runtimepath:append(plugin)

local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/.ltex', 'p')
vim.fn.writefile({ 'existing-word' }, root .. '/.ltex/ltex.dictionary.en-US.txt')
vim.fn.chdir(root)

local notifications = {}
local clients = {}
local attached = {}
local function new_client(id)
  local client = { id = id, name = 'ltex_plus', config = { settings = {} }, stopped = false }
  function client:is_stopped() return self.stopped end
  function client:notify(method, params)
    assert(method == 'workspace/didChangeConfiguration')
    notifications[#notifications + 1] = { id = self.id, params = vim.deepcopy(params) }
    return true
  end
  clients[id] = client
  return client
end
local original_get_client_by_id, original_get_clients = vim.lsp.get_client_by_id, vim.lsp.get_clients
vim.lsp.get_client_by_id = function(id) return clients[id] end
vim.lsp.get_clients = function(filter)
  local client = attached[filter.bufnr]
  return client and client.name == filter.name and { client } or {}
end

local function drain()
  local done = false
  vim.schedule(function() done = true end)
  assert(vim.wait(1000, function() return done end), 'scheduled callbacks did not finish')
end
local function expect_client_since(start, id, count)
  assert(#notifications - start == count, 'unexpected notification count')
  for i = start + 1, #notifications do
    assert(notifications[i].id == id, 'updated the wrong client after a buffer switch')
    assert(notifications[i].params.settings.ltex, 'missing settings notification envelope')
  end
end

local first, second = new_client(1), new_client(2)
local file = vim.api.nvim_get_current_buf()
local sidebar = vim.api.nvim_create_buf(false, true)
attached[file] = first
attached[sidebar] = second -- A different client must not receive the update either.
local compat = require('custom.ltex_extra')
compat.on_attach(first)
vim.api.nvim_set_current_buf(sidebar)
drain()
expect_client_since(0, 1, 3)
assert(vim.deep_equal(first.config.settings.ltex.dictionary['en-US'], { 'existing-word' }))

-- Each registered command uses its context's client, not the selected buffer.
local cases = {
  { '_ltex.addToDictionary', 'words', 'dictionary', 'new-word' },
  { '_ltex.disableRules', 'ruleIds', 'disabledRules', 'RULE_1' },
  { '_ltex.hideFalsePositives', 'falsePositives', 'hiddenFalsePositives', '{"rule":"RULE_2"}' },
}
for _, case in ipairs(cases) do
  local start = #notifications
  vim.lsp.commands[case[1]]({ arguments = { { [case[2]] = { ['en-US'] = { case[4] } } } } },
    { client_id = first.id, bufnr = file })
  drain()
  expect_client_since(start, 1, 1)
  assert(vim.tbl_contains(first.config.settings.ltex[case[3]]['en-US'], case[4]))
  local saved = vim.fn.readfile(root .. '/.ltex/ltex.' .. case[3] .. '.en-US.txt')
  assert(vim.tbl_contains(saved, case[4]), 'command did not persist its entry')
end

-- Public reload captures the current client synchronously, before switching.
local commands = require('ltex_extra.commands-lsp')
vim.api.nvim_set_current_buf(file)
local start = #notifications
require('ltex_extra').reload()
vim.api.nvim_set_current_buf(sidebar)
drain()
expect_client_since(start, 1, 3)

-- A later attach must load the new client, not reuse the first one.
start = #notifications
compat.on_attach(second)
vim.api.nvim_set_current_buf(file)
drain()
expect_client_since(start, 2, 3)

-- Stopping the captured client before a callback runs is safe.
start = #notifications
commands.reload(nil, first)
first.stopped = true
drain()
expect_client_since(start, 1, 0)

-- No attached client (a real sidebar) and stale command contexts are harmless.
attached[sidebar] = nil
vim.api.nvim_set_current_buf(sidebar)
commands.reload()
commands.updateConfig('dictionary', 'en-US')
vim.lsp.commands['_ltex.addToDictionary']({ arguments = { { words = { ['en-US'] = { 'ignored' } } } } },
  { client_id = 999, bufnr = file })
drain()
expect_client_since(start, 1, 0)

vim.lsp.get_client_by_id, vim.lsp.get_clients = original_get_client_by_id, original_get_clients
vim.fn.chdir(config)
vim.fn.delete(root, 'rf')
print('PASS: initial load, all dictionary commands, persistence, reload, multiple clients, buffer switches, stopped/missing clients')
