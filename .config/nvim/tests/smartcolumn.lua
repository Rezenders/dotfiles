-- Run from the config directory: nvim --clean -l tests/smartcolumn.lua
-- Exercise the installed plugin with the actual options from the UI module.
local source = table.concat(vim.fn.readfile 'lua/custom/plugins/ui.lua', '\n')
assert(loadfile 'init.lua')
local setup = assert(source:match("(  require%('smartcolumn'%).setup {.-\n  })"))
local plugin = vim.fn.stdpath 'data' .. '/site/pack/core/opt/smartcolumn.nvim'
assert(vim.fn.isdirectory(plugin) == 1, 'Install smartcolumn.nvim via vim.pack first')
vim.opt.runtimepath:prepend(plugin)
assert(loadstring(setup))()

local function check(ft, width, editorconfig, expected)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].filetype = ft
  vim.b[buf].editorconfig = editorconfig
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'short', string.rep('x', width) })
  local textwidth = vim.bo[buf].textwidth
  vim.api.nvim_exec_autocmds('BufEnter', { buffer = buf })
  assert(vim.wo.colorcolumn == expected, ('%s width %d: expected %q, got %q'):format(ft, width, expected, vim.wo.colorcolumn))
  assert(vim.bo[buf].textwidth == textwidth, 'Smartcolumn must not change textwidth')
  return buf
end

check('markdown', 80, nil, '')
local buf = check('markdown', 81, nil, '80')
-- Hides again when the long line is shortened.
vim.api.nvim_buf_set_lines(buf, 1, 2, false, { 'short' })
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = buf })
assert(vim.wo.colorcolumn == '')
check('ruby', 90, nil, '')
check('ruby', 91, nil, '90')
check('ruby', 101, { max_line_length = '100' }, '100')
check('lua', 81, nil, '80')
check('text', 81, nil, '80')
check('help', 120, nil, '')
check('markdown', 90, { max_line_length = '100' }, '')
check('markdown', 101, { max_line_length = '100' }, '100')
print 'Smartcolumn tests passed: fallback, Markdown/text, help exclusion, whole-file scope, EditorConfig precedence, unchanged textwidth'
