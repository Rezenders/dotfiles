-- Run from the config directory: nvim --clean -l tests/editing.lua
-- Exercise the installed mini modules, not mocks of their editing behavior.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:prepend(vim.fn.stdpath 'data' .. '/site')
vim.g.mapleader = ' '
local add = vim.pack.add
---@diagnostic disable-next-line: duplicate-set-field
vim.pack.add = function(plugins)
  for _, spec in ipairs(plugins) do
    local src = type(spec) == 'table' and spec.src or spec
    local name = src:match '([^/]+)$'
    assert(vim.fn.isdirectory(vim.fn.stdpath 'data' .. '/site/pack/core/opt/' .. name) == 1, 'Missing plugin: ' .. name)
  end
  add(plugins, { load = true })
end
require('custom.keymaps').setup()
require('custom.plugins.editing').setup()
local close = vim.fn.maparg(' x', 'n', false, true).callback
local function keys(input) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(input, true, false, true), 'xt', false) end

-- Removing a buffer shown in two splits must preserve both window IDs and the tree split.
local target = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(target, 0, -1, false, { 'saved content' })
vim.bo[target].modified = false
vim.cmd.vsplit()
vim.cmd.split()
local tree_win = vim.api.nvim_get_current_win()
local tree = vim.api.nvim_create_buf(false, true)
vim.api.nvim_win_set_buf(tree_win, tree)
vim.bo[tree].filetype = 'neo-tree'
vim.cmd.wincmd 'w'
local windows = vim.api.nvim_list_wins()
close()
assert(not vim.bo[target].buflisted, 'Closed buffer should no longer be listed')
assert(vim.deep_equal(windows, vim.api.nvim_list_wins()), 'Buffer deletion changed split layout')
assert(vim.api.nvim_win_get_buf(tree_win) == tree, 'Tree window changed')
for _, win in ipairs(windows) do
  assert(vim.api.nvim_win_get_buf(win) ~= target)
end

-- Declining mini.bufremove's default-No prompt leaves edits and layout untouched.
local modified = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(modified, 0, -1, false, { 'unsaved content' })
local confirm = vim.fn.confirm
---@diagnostic disable-next-line: duplicate-set-field
vim.fn.confirm = function(_, choices, default)
  assert(choices == '&No\n&Yes' and default == 1)
  return 1
end
close()
vim.fn.confirm = confirm
assert(vim.bo[modified].modified and vim.bo[modified].buflisted)
assert(vim.api.nvim_get_current_buf() == modified)
assert(vim.deep_equal(windows, vim.api.nvim_list_wins()))

vim.cmd.only()
vim.bo.expandtab, vim.bo.shiftwidth = true, 2
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local t = { one, two }' })
vim.api.nvim_win_set_cursor(0, { 1, 12 })
assert(MiniSplitjoin.config.mappings.toggle == 'gS')
keys 'gS'
assert(vim.api.nvim_buf_line_count(0) > 1, 'gS should split the table')
keys 'gS'
assert(vim.api.nvim_buf_line_count(0) == 1, 'gS should join the table')

assert(MiniMove.config.options.reindent_linewise)
for _, mode in ipairs { 'n', 'x' } do
  for _, direction in ipairs { 'h', 'j', 'k', 'l' } do
    assert(vim.fn.maparg(' m' .. direction, mode) ~= '', 'Missing move mapping')
    assert(vim.fn.maparg('<A-' .. direction .. '>', mode) == '', 'Move must not claim split-resize keys')
  end
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three', 'four' })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
keys ' mj'
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'two', 'one', 'three', 'four' }))
vim.api.nvim_win_set_cursor(0, { 2, 0 })
keys 'Vj mj<Esc>'
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'two', 'four', 'one', 'three' }))
print 'Editing tests passed: layout-preserving deletion, unsaved protection, split/join and normal/visual movement'
