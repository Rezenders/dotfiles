-- Run from the config directory: nvim --clean -l tests/line_length.lua
local config = vim.fn.getcwd()
vim.opt.runtimepath:prepend(config)
local executable = vim.fn.exepath 'markdownlint'
if executable == '' then executable = vim.fn.stdpath 'data' .. '/mason/bin/markdownlint' end
assert(vim.fn.executable(executable) == 1, 'Install markdownlint (Mason or PATH) to run these tests')
assert(vim.fn.executable 'node' == 1, 'Node is required')

local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
vim.fn.chdir(root)
vim.env.HOME = root
vim.env.XDG_CONFIG_HOME = root
package.loaded.lint = {
  linters_by_ft = { markdown = { 'markdownlint' } },
  linters = { markdownlint = { cmd = executable, args = { '--stdin' } } },
}
local guide = require 'custom.line_length'
local function expect(column)
  assert(vim.wait(5000, function() return vim.wo.colorcolumn == column end, 10),
    ('Expected colorcolumn %q, got %q'):format(column, vim.wo.colorcolumn))
end
local function configure(lines, name)
  vim.fn.writefile(lines, name or '.markdownlint.json')
  guide.invalidate()
end

local ok, err = xpcall(function()
  vim.bo.filetype = 'markdown'
  guide.setup()
  expect '81'
  -- Wait for the default-config asynchronous lookup to finish before continuing.
  vim.wait(300)
  configure { '{ "MD013": { "line_length": 100 } }' }
  expect '101'
  configure { '{ "MD013": false }' }
  expect ''
  configure { '{ "default": false }' }
  expect ''
  configure { '{ "default": false, "line-length": { "line_length": 88 } }' }
  expect '89'
  configure { '{ "MD013": { "enabled": false } }' }
  expect ''

  vim.fn.writefile({ '{ "MD013": { "line_length": 96 } }' }, 'base.json')
  configure { '{ "extends": "base.json" }' }
  expect '97'
  vim.fn.delete '.markdownlint.json'
  configure({ 'MD013:', '  line_length: 72' }, '.markdownlint.yaml')
  expect '73'
  vim.fn.delete '.markdownlint.yaml'
  configure({ '// comments and trailing commas', '{ "MD013": { "line_length": 90, }, }' }, '.markdownlint.jsonc')
  expect '91'

  -- Overrides do not change linting, wrapping, or textwidth.
  local textwidth, wrap = vim.bo.textwidth, vim.wo.wrap
  vim.b.line_length_limit = 60
  guide.refresh()
  expect '61'
  vim.b.line_length_limit = false
  guide.refresh()
  expect ''
  vim.b.line_length_limit = nil
  guide.refresh()
  expect '91'
  assert(vim.bo.textwidth == textwidth and vim.wo.wrap == wrap)

  local markdown_buf = vim.api.nvim_get_current_buf()
  local markdown_win = vim.api.nvim_get_current_win()
  vim.cmd 'vnew'
  vim.bo.filetype = 'python'
  guide.refresh()
  expect '81'
  assert(vim.wo[markdown_win].colorcolumn == '91', 'Split windows must keep independent guides')
  vim.bo.buftype = 'nofile'
  guide.refresh()
  expect ''
  vim.bo.buftype = ''
  vim.api.nvim_set_current_buf(markdown_buf)
  guide.refresh()
  expect '91'

  -- Config saves invalidate the cache, including arbitrary inheritance filenames.
  vim.fn.writefile({ '{ "MD013": { "line_length": 110 } }' }, '.markdownlint.jsonc')
  vim.api.nvim_exec_autocmds('BufWritePost', { buffer = markdown_buf })
  expect '111'

  -- A different window-local cwd must resolve independently, like nvim-lint.
  vim.fn.mkdir('other', 'p')
  vim.cmd('lcd ' .. vim.fn.fnameescape(root .. '/other'))
  guide.invalidate()
  expect '81'
  assert(vim.wait(5000, function() return vim.wo[markdown_win].colorcolumn == '111' end, 10))

  -- Unsupported custom CLI arguments use the fallback, not a guessed limit.
  package.loaded.lint.linters.markdownlint.args = { '--stdin', '--disable', 'MD013' }
  guide.invalidate()
  expect '81'
end, debug.traceback)
vim.fn.chdir(config)
vim.fn.delete(root, 'rf')
assert(ok, err)
print('line_length: all tests passed')
