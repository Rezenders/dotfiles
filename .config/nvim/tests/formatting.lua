-- Run from the config directory: nvim --clean -l tests/formatting.lua
-- Installed Conform; mock dispatch and Ruby tooling, then run real formatters in temp projects.
---@diagnostic disable: duplicate-set-field
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local plugin = vim.fn.stdpath 'data' .. '/site/pack/core/opt/conform.nvim'
assert(vim.fn.isdirectory(plugin) == 1, 'Install conform.nvim via vim.pack first')
vim.opt.runtimepath:prepend(plugin)
vim.g.mapleader = ' '
vim.pack.add = function(specs) assert(vim.deep_equal(specs, { 'https://github.com/stevearc/conform.nvim' })) end
local notices = {}
vim.notify = function(message) notices[#notices + 1] = message end
local workflow = require 'custom.plugins.formatting'
workflow.setup()
local conform = require 'conform'
assert(vim.deep_equal(conform.formatters_by_ft, {
  markdown = { 'prettier' },
  lua = { 'stylua' },
  python = { 'ruff_format' },
  ruby = { 'rubocop' },
}))
assert(conform.default_format_opts.lsp_format == 'never' and conform.notify_no_formatters)
assert(#vim.api.nvim_get_autocmds { group = 'Conform', event = 'BufWritePre' } == 0)
assert(#vim.api.nvim_get_autocmds { group = 'Conform', event = 'BufWritePost' } == 0)
local function callback(key) return vim.fn.maparg(key, 'n', false, true).callback end
assert(callback ' cf' == workflow.format and callback ' mf' == workflow.format)
local original_format, original_get_clients, original_lsp_format = conform.format, vim.lsp.get_clients, vim.lsp.buf.format
local last, lsp_last, texlab = nil, nil, false
conform.format = function(options) last = options end
vim.lsp.get_clients = function(filter)
  assert(filter.name == 'texlab' and filter.method == 'textDocument/formatting')
  assert(filter.bufnr == vim.api.nvim_get_current_buf())
  return texlab and { { name = 'texlab' } } or {}
end
vim.lsp.buf.format = function(options) lsp_last = options end
local function buffer(ft, path, lines)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  if path then vim.api.nvim_buf_set_name(buf, path) end
  vim.bo.filetype = ft
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { 'content' })
  return buf
end
for _, ft in ipairs { 'markdown', 'lua', 'python', 'ruby' } do
  local buf = buffer(ft)
  callback ' cf'()
  assert(vim.deep_equal(last, { bufnr = buf, async = true }))
end
for _, ft in ipairs { 'tex', 'plaintex' } do
  local buf = buffer(ft)
  last, lsp_last = nil, nil
  workflow.format()
  assert(not last and not lsp_last and notices[#notices]:find('TexLab', 1, true))
  texlab = true
  workflow.format()
  assert(not last and lsp_last.bufnr == buf and lsp_last.async)
  assert(lsp_last.filter { name = 'texlab' } and not lsp_last.filter { name = 'ltex_plus' })
  texlab = false
end
buffer 'tex'
assert(loadfile 'after/ftplugin/tex.lua')()
assert(callback ' lf' == workflow.format, 'LaTeX alias must use the same entry point')
last, lsp_last = nil, nil
vim.bo.modifiable = false
workflow.format()
assert(not last and not lsp_last)
vim.bo.modifiable, vim.bo.buftype = true, 'nofile'
workflow.format()
assert(not last and not lsp_last)
vim.bo.buftype = ''
conform.format, vim.lsp.get_clients, vim.lsp.buf.format = original_format, original_get_clients, original_lsp_format

local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local ok, err = xpcall(function()
  local ruby = root .. '/ruby'
  vim.fn.mkdir(ruby .. '/lib', 'p')
  vim.fn.writefile({}, ruby .. '/Gemfile')
  local buf = buffer('ruby', ruby .. '/lib/example.rb')
  local config = assert(conform.get_formatter_config('rubocop', buf))
  assert(config.command == 'bundle' and config.cwd() == ruby)
  local runner = require 'conform.runner'
  local cmd = runner.build_cmd('rubocop', runner.build_context(buf, config), config)
  assert(cmd[2] == 'exec' and cmd[3] == 'rubocop', 'Bundler must use the project version')
  assert(vim.list_contains(cmd, '-a') and not vim.list_contains(cmd, '-A'), 'Use safe autocorrection only')
  vim.fn.mkdir(ruby .. '/bin', 'p')
  vim.fn.writefile({ '#!/bin/sh', 'exit 0' }, ruby .. '/bin/rubocop')
  assert(vim.uv.fs_chmod(ruby .. '/bin/rubocop', 493))
  config = assert(conform.get_formatter_config('rubocop', buf))
  assert(config.command == ruby .. '/bin/rubocop' and config.cwd() == ruby, 'Prefer project binstub')
  buffer('ruby', root .. '/standalone.rb')
  config = assert(conform.get_formatter_config 'rubocop')
  assert(type(config.command) == 'function')
  assert(config.command(config, { dirname = root }) == 'rubocop', 'Standalone files may use PATH RuboCop')

  -- No formatter or missing command must warn, never use an unrelated language server.
  buffer 'unsupported-format-test'
  workflow.format()
  assert(vim.wait(1000, function()
    for _, message in ipairs(notices) do
      if message:find('no formatter available', 1, true) then return true end
    end
    return false
  end))
  buffer('ruby', ruby .. '/lib/missing.rb')
  vim.fn.delete(ruby .. '/bin/rubocop')
  local executable = vim.fn.executable
  vim.fn.executable = function(command) return command == 'bundle' and 0 or executable(command) end
  local info = conform.get_formatter_info('rubocop', 0)
  assert(not info.available and info.command == 'bundle')
  local count = #notices
  workflow.format()
  assert(#notices == count + 1 and notices[#notices]:find('no formatter available for ruby', 1, true))
  vim.fn.executable = executable

  local function real_format(ft, dirname, filename, configfile, configlines, input, check)
    vim.fn.mkdir(dirname, 'p')
    vim.fn.writefile(configlines, dirname .. '/' .. configfile)
    local buf = buffer(ft, dirname .. '/' .. filename, input)
    local done, failure = false, nil
    conform.format = function(options)
      assert(options.async and options.bufnr == buf)
      return original_format(options, function(error)
        failure, done = error, true
      end)
    end
    workflow.format()
    assert(vim.wait(10000, function() return done end, 10), 'Async formatter timed out: ' .. ft)
    assert(not failure, tostring(failure))
    check(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end
  for _, command in ipairs { 'stylua', 'ruff', 'prettier' } do
    assert(vim.fn.executable(command) == 1, 'Install ' .. command .. ' via Mason or PATH to run integration tests')
  end
  real_format('lua', root .. '/lua', 'test.lua', '.stylua.toml', {
    'quote_style = "ForceSingle"',
  }, { 'local x={foo="bar"}' }, function(lines) assert(lines[1] == "local x = { foo = 'bar' }", 'StyLua must honor project configuration') end)
  real_format('python', root .. '/python', 'test.py', 'pyproject.toml', {
    '[tool.ruff.format]',
    'quote-style = "single"',
  }, { 'x={"foo":"bar"}' }, function(lines) assert(lines[1] == "x = {'foo': 'bar'}", 'Ruff must honor project configuration') end)
  real_format('markdown', root .. '/markdown', 'test.md', '.prettierrc.json', {
    '{ "proseWrap": "always", "printWidth": 20 }',
  }, { 'one two three four five six seven eight nine ten eleven twelve' }, function(lines)
    assert(#lines > 1, 'Prettier must honor project prose wrapping')
    for _, line in ipairs(lines) do
      assert(#line <= 20)
    end
  end)
end, debug.traceback)
conform.format = original_format
vim.fn.delete(root, 'rf')
assert(ok, err)
print 'Formatting tests passed: async aliases, explicit ownership, no save hooks, TexLab-only routing, Ruby command selection, actual StyLua/Ruff/Prettier project configs'
