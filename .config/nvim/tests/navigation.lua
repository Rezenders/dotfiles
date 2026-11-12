-- Run from the config directory: nvim --clean -l tests/navigation.lua
-- Exercise search, explorer, and Markdown modules without plugins.
---@diagnostic disable: duplicate-set-field
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.g.mapleader = ' '
local added, calls, configs, notices = {}, {}, {}, {}
vim.pack.add = function(plugins)
  for _, spec in ipairs(plugins) do
    local src = type(spec) == 'table' and spec.src or spec
    added[src:match('([^/]+)$')] = spec
  end
end
vim.notify = function(message) notices[#notices + 1] = message end
local fzf = setmetatable({
  setup = function(options) configs.fzf = options end,
  register_ui_select = function() calls.ui_select = true end,
}, { __index = function(_, name) return function(options) calls[name] = options or true end end })
package.loaded['fzf-lua'] = fzf
package.loaded['neo-tree'] = { setup = function(options) configs.explorer = options end }
package.loaded.markview = { setup = function(options) configs.markview = options end }
local search = require 'custom.plugins.search'
assert(next(added) == nil, 'Require must not initialize plugins')
search.setup()
assert(added['fzf-lua'] and calls.ui_select)
assert(configs.fzf.fzf_colors and configs.fzf.fzf_opts['--no-scrollbar'])
assert(configs.fzf.winopts.preview.flip_columns == 135)
local function invoke(lhs, mode)
  local mapping = vim.fn.maparg(lhs, mode or 'n', false, true)
  assert(type(mapping.callback) == 'function', 'Missing callback for ' .. lhs)
  mapping.callback()
end
invoke(' /')
assert(vim.deep_equal(calls.blines, { previewer = false }))
invoke(' sn')
assert(calls.files.cwd == vim.fn.stdpath 'config')
invoke(' s/')
assert(not calls.live_grep and notices[#notices] == 'No open files to search')
local path = vim.fn.tempname()
vim.fn.writefile({ 'searchable' }, path)
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, path)
invoke(' s/')
assert(vim.deep_equal(calls.live_grep.search_paths, { path }))
vim.fn.delete(path)
vim.api.nvim_exec_autocmds('LspAttach', { group = 'fzf-lua-lsp-attach', buffer = buf })
vim.api.nvim_set_current_buf(buf)
invoke('grd')
assert(calls.lsp_definitions, 'LSP picker mappings must be buffer-local and functional')
assert(vim.fn.maparg(' bb', 'n') == '<C-^>')

require('custom.plugins.file_explorer').setup()
assert(added['neo-tree.nvim'].version and added['plenary.nvim'] and added['nui.nvim'])
assert(vim.fn.maparg('\\', 'n'):lower() == '<cmd>neotree reveal<cr>')
local mappings = configs.explorer.filesystem.window.mappings
assert(mappings['\\'] == 'close_window')
local copied
vim.fn.setreg = function(register, value) assert(register == '+'); copied = value end
mappings.Y { tree = { get_node = function() return { get_id = function() return vim.fn.getcwd() .. '/test.txt' end } end } }
assert(copied == 'test.txt' and notices[#notices] == 'Copied: test.txt')
assert(configs.explorer.source_selector.winbar and not configs.explorer.source_selector.statusline)
vim.wo.list, vim.wo.cursorline = true, true
vim.api.nvim_exec_autocmds('FileType', { pattern = 'neo-tree-popup' })
assert(not vim.wo.list and not vim.wo.cursorline)

require('custom.plugins.markdown').setup()
assert(vim.deep_equal(configs.markview, {}))
assert(vim.fn.maparg(' mp', 'n'):lower() == '<cmd>markview<cr>')
assert(vim.fn.maparg(' ms', 'n'):lower() == '<cmd>markview splittoggle<cr>')
print 'Navigation/Markdown tests passed: picker options, open-file search, LSP mappings, explorer copy/popup and preview mappings'
