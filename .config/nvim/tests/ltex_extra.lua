-- Run from the config directory: nvim --clean -l tests/ltex_extra.lua
local config = vim.fn.getcwd()
vim.opt.runtimepath:prepend(config)
local plugin = vim.fn.glob(vim.fn.stdpath('data') .. '/site/pack/*/opt/ltex_extra.nvim', false, true)[1]
assert(plugin, 'ltex_extra.nvim must be installed to run this regression test')
vim.opt.runtimepath:append(plugin)

local root = vim.fn.tempname()
local first_root, second_root = root .. '/first', root .. '/second'
local cases = {
  { '_ltex.addToDictionary', 'words', 'dictionary', 'new-word' },
  { '_ltex.disableRules', 'ruleIds', 'disabledRules', 'RULE_1' },
  { '_ltex.hideFalsePositives', 'falsePositives', 'hiddenFalsePositives', '{"rule":"RULE_2"}' },
}
local function dictionary_file(project, kind)
  return project .. '/.ltex/ltex.' .. kind .. '.en-US.txt'
end
for _, project in ipairs { first_root, second_root } do
  vim.fn.mkdir(project .. '/.ltex', 'p')
  for _, case in ipairs(cases) do
    vim.fn.writefile({ project == first_root and 'first-entry' or 'second-entry' }, dictionary_file(project, case[3]))
  end
end
vim.fn.chdir(first_root)

local notifications = {}
local clients = {}
local attached = {}
local function new_client(id, project)
  local client = { id = id, name = 'ltex_plus', config = { root_dir = project, settings = {} }, stopped = false }
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
  if not filter then return {} end
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
local function expect_entries(client, expected)
  for _, case in ipairs(cases) do
    assert(vim.deep_equal(client.config.settings.ltex[case[3]]['en-US'], expected),
      case[3] .. ' loaded entries from the wrong project')
  end
end

local first, second = new_client(1, first_root), new_client(2, second_root)
local file = vim.api.nvim_get_current_buf()
local sidebar = vim.api.nvim_create_buf(false, true)
attached[file] = first
attached[sidebar] = second -- A different client must not receive the update either.
local compat = require('custom.latex.ltex_extra')
compat.on_attach(first)
vim.api.nvim_set_current_buf(sidebar)
vim.fn.chdir(second_root)
drain()
expect_client_since(0, 1, 3)
expect_entries(first, { 'first-entry' })

-- A later attach has its own storage even when another project is current.
local start = #notifications
compat.on_attach(second)
vim.api.nvim_set_current_buf(file)
vim.fn.chdir(first_root)
drain()
expect_client_since(start, 2, 3)
expect_entries(second, { 'second-entry' })

-- Interleaved reloads must retain both roots through a cwd switch.
local commands = require('ltex_extra.commands-lsp')
start = #notifications
commands.reload(nil, first)
commands.reload(nil, second)
vim.fn.chdir(second_root)
drain()
assert(#notifications - start == 6)
expect_entries(first, { 'first-entry' })
expect_entries(second, { 'second-entry' })

-- Each command reads and writes its context's project, not the current one.
for _, target in ipairs {
  { client = first, project = first_root, other = second_root, bufnr = file, other_bufnr = sidebar },
  { client = second, project = second_root, other = first_root, bufnr = sidebar, other_bufnr = file },
} do
  for _, case in ipairs(cases) do
    vim.api.nvim_set_current_buf(target.other_bufnr)
    vim.fn.chdir(target.other)
    local other_before = vim.fn.readfile(dictionary_file(target.other, case[3]))
    start = #notifications
    local entry = case[4] .. '-' .. target.client.id
    vim.lsp.commands[case[1]]({ arguments = { { [case[2]] = { ['en-US'] = { entry } } } } },
      { client_id = target.client.id, bufnr = target.bufnr })
    -- Also change cwd between the synchronous write and scheduled read.
    vim.fn.chdir(root)
    drain()
    expect_client_since(start, target.client.id, 1)
    local saved = vim.fn.readfile(dictionary_file(target.project, case[3]))
    assert(vim.tbl_contains(saved, entry), 'command did not persist its entry in the client project')
    assert(vim.deep_equal(target.client.config.settings.ltex[case[3]]['en-US'], saved))
    assert(vim.deep_equal(vim.fn.readfile(dictionary_file(target.other, case[3])), other_before),
      'command modified another project')
  end
end
assert(vim.fn.isdirectory(root .. '/.ltex') == 0, 'scheduled work created storage in the current cwd')

-- Public reload captures the current client synchronously, before switching.
vim.api.nvim_set_current_buf(file)
vim.fn.chdir(first_root)
start = #notifications
require('ltex_extra').reload()
vim.api.nvim_set_current_buf(sidebar)
vim.fn.chdir(second_root)
drain()
expect_client_since(start, 1, 3)
assert(vim.deep_equal(first.config.settings.ltex.dictionary['en-US'], vim.fn.readfile(dictionary_file(first_root, 'dictionary'))))

-- Direct updates also use the client root, not the current project.
start = #notifications
commands.updateConfig('dictionary', 'en-US', first)
expect_client_since(start, 1, 1)
assert(vim.deep_equal(first.config.settings.ltex.dictionary['en-US'], vim.fn.readfile(dictionary_file(first_root, 'dictionary'))))

-- Rootless clients keep the cwd captured at attach, including later commands.
local rootless_root = root .. '/rootless'
vim.fn.mkdir(rootless_root, 'p')
vim.fn.chdir(rootless_root)
local rootless = new_client(3)
start = #notifications
compat.on_attach(rootless)
vim.fn.chdir(second_root)
drain()
expect_client_since(start, 3, 3)
expect_entries(rootless, {})
assert(vim.fn.isdirectory(rootless_root .. '/.ltex') == 0, 'loading missing dictionaries created storage')
start = #notifications
vim.lsp.commands['_ltex.addToDictionary']({ arguments = { { words = { ['en-US'] = { 'rootless-word' } } } } },
  { client_id = rootless.id })
drain()
expect_client_since(start, 3, 1)
assert(vim.tbl_contains(vim.fn.readfile(dictionary_file(rootless_root, 'dictionary')), 'rootless-word'))
assert(not vim.tbl_contains(vim.fn.readfile(dictionary_file(second_root, 'dictionary')), 'rootless-word'))

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
print('PASS: per-project reads/writes, cwd switches, all dictionary commands, reload, rootless clients, stopped/missing clients')
