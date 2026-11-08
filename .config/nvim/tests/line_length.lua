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
local system = vim.system
local lookups = 0
vim.system = function(...)
  lookups = lookups + 1
  return system(...)
end
local function saved(name) vim.api.nvim_exec_autocmds('BufWritePost', { pattern = root .. '/' .. name }) end
local function expect(column)
  assert(vim.wait(5000, function() return vim.wo.colorcolumn == column end, 10), ('Expected colorcolumn %q, got %q'):format(column, vim.wo.colorcolumn))
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

  -- Unrelated saves must not spawn a configuration resolver.
  local before = lookups
  saved 'unrelated.py'
  vim.wait(250)
  assert(lookups == before, 'Unrelated saves must preserve the cache')

  -- Bursts coalesce, keeping the previous guide while waiting and resolving.
  vim.fn.writefile({ '{ "MD013": { "line_length": 110 } }' }, '.markdownlint.jsonc')
  for _ = 1, 5 do
    saved '.markdownlint.jsonc'
  end
  guide.refresh()
  assert(vim.wo.colorcolumn == '91', 'Refreshing must not reset the guide to 80')
  assert(lookups == before, 'Save invalidation should be debounced')
  expect '111'
  assert(lookups == before + 1, 'A burst should perform one lookup')

  -- Nested inherited files may have arbitrary names.
  vim.fn.writefile({ '{ "MD013": { "line_length": 112 } }' }, 'policy.data')
  vim.fn.writefile({ '{ "extends": "policy.data" }' }, 'base.json')
  vim.fn.writefile({ '{ "extends": "base.json" }' }, '.markdownlint.jsonc')
  saved '.markdownlint.jsonc'
  expect '113'
  vim.fn.writefile({ '{ "MD013": { "line_length": 110 } }' }, 'policy.data')
  saved 'policy.data'
  expect '111'

  -- Focus refreshes are also debounced and keep the last known limit.
  before = lookups
  for _ = 1, 5 do
    vim.api.nvim_exec_autocmds('FocusGained', {})
  end
  assert(vim.wo.colorcolumn == '111')
  assert(vim.wait(5000, function() return lookups == before + 1 end, 10))
  vim.wait(300)
  assert(lookups == before + 1)

  -- A newly created higher-priority candidate must also be a dependency.
  vim.fn.delete '.markdownlint.jsonc'
  guide.invalidate()
  expect '81'
  vim.fn.writefile({ '{ "MD013": { "line_length": 110 } }' }, '.markdownlint.jsonc')
  saved '.markdownlint.jsonc'
  expect '111'

  -- An invalidation during an in-flight lookup must reject its stale result.
  local release
  vim.system = function(command, options, callback)
    lookups = lookups + 1
    return system(command, options, function(result)
      release = function() callback(result) end
    end)
  end
  guide.invalidate()
  assert(vim.wait(5000, function() return release ~= nil end, 10))
  vim.system = function(...)
    lookups = lookups + 1
    return system(...)
  end
  vim.fn.writefile({ '{ "MD013": { "line_length": 114 } }' }, '.markdownlint.jsonc')
  saved '.markdownlint.jsonc'
  release()
  vim.wait(20)
  assert(vim.wo.colorcolumn == '111', 'A stale result must not replace the previous guide')
  expect '115'
  vim.fn.writefile({ '{ "extends": "base.json" }' }, '.markdownlint.jsonc')
  saved '.markdownlint.jsonc'
  expect '111'

  -- A different window-local cwd must resolve independently, like nvim-lint.
  vim.fn.mkdir('other', 'p')
  vim.cmd('lcd ' .. vim.fn.fnameescape(root .. '/other'))
  guide.invalidate()
  expect '81'
  assert(vim.wait(5000, function() return vim.wo[markdown_win].colorcolumn == '111' end, 10))

  -- Only the cwd whose dependency changed is resolved again.
  vim.wait(300)
  before = lookups
  vim.fn.writefile({ '{ "MD013": { "line_length": 116 } }' }, root .. '/policy.data')
  saved 'policy.data'
  assert(vim.wait(5000, function() return vim.wo[markdown_win].colorcolumn == '117' end, 10))
  assert(vim.wo.colorcolumn == '81')
  assert(lookups == before + 1, 'Dependency saves must invalidate only affected entries')

  -- run-con's missing rc candidates are tracked as well as markdownlint configs.
  vim.fn.writefile({ '{ "MD013": { "line_length": 92 } }' }, '.markdownlintrc')
  saved 'other/.markdownlintrc'
  expect '93'

  -- Unsupported custom CLI arguments use the fallback, not a guessed limit.
  package.loaded.lint.linters.markdownlint.args = { '--stdin', '--disable', 'MD013' }
  guide.invalidate()
  expect '81'
end, debug.traceback)
vim.system = system
vim.fn.chdir(config)
vim.fn.delete(root, 'rf')
assert(ok, err)
print 'line_length: all tests passed'
