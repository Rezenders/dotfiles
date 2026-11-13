-- Run from the config directory: nvim --clean -l tests/core.lua
-- Exercise core behavior and build hooks without desktop queries or builds.
---@diagnostic disable: duplicate-set-field
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local commands, notices, builds = {}, {}, {}
local original_cmd = vim.cmd
vim.cmd = setmetatable({
  packadd = function(name) commands[#commands + 1] = 'packadd ' .. name end,
}, {
  __index = original_cmd,
  __call = function(_, command)
    if command == 'TSUpdate' then commands[#commands + 1] = command else original_cmd(command) end
  end,
})
package.loaded['vim._core.ui2'] = { enable = function(options) assert(vim.deep_equal(options, {})) end }
local file_setup = false
package.loaded['custom.file_autocmds'] = { setup = function() file_setup = true end }
vim.notify = function(message, level) notices[#notices + 1] = { message, level } end
require('custom.options').setup()
require('custom.keymaps').setup()
require('custom.autocmds').setup()
assert(vim.g.mapleader == ' ' and vim.g.maplocalleader == ' ')
assert(vim.o.undofile and vim.o.undolevels == 10000 and commands[1] == 'packadd nvim.undotree')
assert(vim.fn.maparg(' u', 'n'):lower() == '<cmd>undotree<cr>')
local deletion
package.loaded['mini.bufremove'] = { delete = function(buf, force) deletion = { buf, force } end }
vim.fn.maparg(' x', 'n', false, true).callback()
assert(vim.deep_equal(deletion, { 0, false }), 'Buffer deletion must preserve layout without forcing')
assert(vim.fn.maparg('<C-/>', 'n') == 'gcc' and vim.fn.maparg('<C-/>', 'x') == 'gc')
assert(file_setup, 'File conveniences must be registered')
local diagnostics = vim.diagnostic.config()
assert(not diagnostics.virtual_text and not diagnostics.virtual_lines and diagnostics.underline)
assert(#vim.api.nvim_get_autocmds { event = 'TextYankPost', group = 'kickstart-highlight-yank' } == 1)
local function trim(ft, buftype, binary, expected)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.bo.filetype, vim.bo.buftype, vim.bo.binary = ft, buftype, binary
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'content   ' })
  vim.api.nvim_exec_autocmds('BufWritePre', { buffer = buf, group = 'trim-trailing-whitespace' })
  assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == expected, 'Unexpected whitespace trimming for ' .. ft)
end
trim('lua', '', false, 'content')
for _, ft in ipairs { 'markdown', 'rmd', 'quarto', 'diff', 'gitcommit' } do trim(ft, '', false, 'content   ') end
trim('lua', 'nofile', false, 'content   ')
trim('lua', '', true, 'content   ')

local win32, make, code = false, true, 0
vim.fn.has = function(feature) return feature == 'win32' and win32 and 1 or 0 end
vim.fn.executable = function(exe) return exe == 'make' and make and 1 or 0 end
vim.system = function(args, options)
  builds[#builds + 1] = { args = args, cwd = options.cwd }
  return { wait = function() return { code = code, stderr = 'build stderr', stdout = 'build stdout' } end }
end
require('custom.pack_hooks').setup()
local function changed(name, kind, active)
  vim.api.nvim_exec_autocmds('PackChanged', {
    data = { spec = { name = name }, kind = kind, active = active, path = '/test/plugin' },
  })
end
changed('LuaSnip', 'install', false)
assert(vim.deep_equal(builds[1], { args = { 'make', 'install_jsregexp' }, cwd = '/test/plugin' }))
win32 = true
changed('LuaSnip', 'update', true)
win32, make = false, false
changed('LuaSnip', 'install', false)
changed('LuaSnip', 'delete', false)
assert(#builds == 1, 'Unsupported build conditions must be skipped')
make, code = true, 1
changed('LuaSnip', 'update', true)
assert(notices[#notices][1]:find('build stderr', 1, true) and notices[#notices][2] == vim.log.levels.ERROR)
changed('nvim-treesitter', 'install', false)
assert(commands[#commands - 1] == 'packadd nvim-treesitter' and commands[#commands] == 'TSUpdate')
local count = #commands
changed('nvim-treesitter', 'update', true)
assert(#commands == count + 1 and commands[#commands] == 'TSUpdate')
print 'Core tests passed: leaders/undo/keymaps, diagnostic defaults, whitespace exclusions, file conveniences, guarded build hooks and failures'
