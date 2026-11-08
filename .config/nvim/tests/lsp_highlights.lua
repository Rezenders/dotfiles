-- Run from the config directory: nvim --clean -l tests/lsp_highlights.lua
-- This test deliberately replaces and restores LSP API functions.
---@diagnostic disable: duplicate-set-field
-- Load the actual LspAttach registration without starting servers or plugins.
local source = table.concat(vim.fn.readfile 'init.lua', '\n')
local section = assert(source:match("(  vim%.api%.nvim_create_autocmd%('LspAttach', {\n    group = vim%.api%.nvim_create_augroup%('kickstart%-lsp%-attach'.-)\n\n  %-%- Enable the following language servers"))
assert(loadstring(section))()

local method = 'textDocument/documentHighlight'
local clients, attached = {}, {}
local original_get_client_by_id, original_get_clients = vim.lsp.get_client_by_id, vim.lsp.get_clients
vim.lsp.get_client_by_id = function(id) return clients[id] end
vim.lsp.get_clients = function(filter)
  assert(filter.method == method, 'must query document-highlight capabilities')
  local result = {}
  for id in pairs(attached[filter.bufnr] or {}) do
    local client = clients[id]
    if client:supports_method(filter.method, filter.bufnr) then result[#result + 1] = client end
  end
  return result
end
local function new_client(id, capable)
  local client = { id = id }
  function client:supports_method(request, buf)
    assert(buf and vim.api.nvim_buf_is_valid(buf), 'capability check must target a buffer')
    return request == method and capable
  end
  clients[id] = client
  return client
end
local function attach(buf, client)
  attached[buf] = attached[buf] or {}
  attached[buf][client.id] = true
  vim.api.nvim_exec_autocmds('LspAttach', { buffer = buf, data = { client_id = client.id } })
end
local function detach(buf, client)
  -- Match Client:_on_detach: the client is still listed during LspDetach.
  assert(attached[buf][client.id], 'detaching a client that is not attached')
  vim.api.nvim_exec_autocmds('LspDetach', { buffer = buf, data = { client_id = client.id } })
  attached[buf][client.id] = nil
end
local function expect_handlers(buf, count)
  for _, event in ipairs { 'CursorHold', 'CursorHoldI', 'CursorMoved', 'CursorMovedI', 'LspDetach' } do
    local handlers = vim.api.nvim_get_autocmds { group = 'kickstart-lsp-highlight', buffer = buf, event = event }
    assert(#handlers == count, ('%s: expected %d handlers, got %d'):format(event, count, #handlers))
  end
end

local highlights, clears = {}, {}
local original_highlight, original_clear = vim.lsp.buf.document_highlight, vim.lsp.buf.clear_references
vim.lsp.buf.document_highlight = function() highlights[#highlights + 1] = vim.api.nvim_get_current_buf() end
vim.lsp.buf.clear_references = function()
  clears[#clears + 1] = vim.api.nvim_get_current_buf()
  original_clear()
end
local function new_buffer()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'reference' })
  return buf
end
local function add_reference(buf)
  vim.lsp.util.buf_highlight_references(buf, {
    { kind = 1, range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 3 } } },
  }, 'utf-16')
end
local function reference_count(buf)
  local namespace = assert(vim.api.nvim_get_namespaces()['nvim.lsp.references'])
  return #vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, {})
end

local first, second, incapable = new_client(1, true), new_client(2, true), new_client(3, false)
local target, other, unrelated = new_buffer(), new_buffer(), new_buffer()
vim.api.nvim_set_current_buf(unrelated)
attach(target, incapable)
-- The highlight group is only created on a capable attach.
attach(target, first)
expect_handlers(target, 1)
attach(target, first)
attach(target, second)
expect_handlers(target, 1)
attach(other, first)
expect_handlers(other, 1)

-- Each idle event makes exactly one request, in the event's buffer context.
for _, event in ipairs { 'CursorHold', 'CursorHoldI' } do
  local count = #highlights
  vim.api.nvim_exec_autocmds(event, { buffer = target })
  assert(#highlights == count + 1 and highlights[#highlights] == target)
  assert(vim.api.nvim_get_current_buf() == unrelated)
end
for _, event in ipairs { 'CursorMoved', 'CursorMovedI' } do
  add_reference(target)
  add_reference(unrelated)
  local count = #clears
  vim.api.nvim_exec_autocmds(event, { buffer = target })
  assert(#clears == count + 1 and clears[#clears] == target)
  assert(reference_count(target) == 0 and reference_count(unrelated) > 0)
end

add_reference(target)
local count = #clears
detach(target, incapable)
detach(target, first)
expect_handlers(target, 1)
expect_handlers(other, 1)
assert(#clears == count and reference_count(target) > 0, 'cleared references while a capable client remained')
vim.api.nvim_exec_autocmds('CursorHold', { buffer = target })
assert(highlights[#highlights] == target, 'remaining client lost highlights')
detach(target, second)
expect_handlers(target, 0)
expect_handlers(other, 1)
assert(#clears == count + 1 and clears[#clears] == target)
assert(reference_count(target) == 0 and reference_count(unrelated) > 0)
assert(vim.api.nvim_get_current_buf() == unrelated, 'cleanup changed the current buffer')

-- Reattaching after the final detach recreates exactly one complete set.
for _ = 1, 3 do
  attach(target, incapable)
  expect_handlers(target, 0)
  attach(target, second)
  attach(target, first)
  attach(target, second)
  expect_handlers(target, 1)
  detach(target, second)
  expect_handlers(target, 1)
  detach(target, first)
  expect_handlers(target, 0) -- Incapable clients do not keep the handlers alive.
  detach(target, incapable)
  expect_handlers(target, 0)
end
-- Detaching from one buffer never removes another buffer's handlers.
expect_handlers(other, 1)
detach(other, first)
expect_handlers(other, 0)

-- Buffer-local cleanup also disappears on wipeout, without leaving stale state.
local wiped = new_buffer()
attach(wiped, first)
expect_handlers(wiped, 1)
vim.api.nvim_buf_delete(wiped, { force = true })
local replacement = new_buffer()
attach(replacement, first)
expect_handlers(replacement, 1)
detach(replacement, first)
expect_handlers(replacement, 0)

vim.lsp.get_client_by_id, vim.lsp.get_clients = original_get_client_by_id, original_get_clients
vim.lsp.buf.document_highlight, vim.lsp.buf.clear_references = original_highlight, original_clear
print 'LSP highlight regression tests passed: multiple clients/buffers, detach timing, reference context, repeated lifecycle, wipeout'
