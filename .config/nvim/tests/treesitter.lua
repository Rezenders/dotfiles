-- Run from the config directory: nvim --clean -l tests/treesitter.lua
-- Exercise the real setup section without downloading plugins or loading parsers.
local source = table.concat(vim.fn.readfile 'init.lua', '\n')
local section = assert(source:match('(do\n  vim%.pack%.add { { src = gh \'nvim%-treesitter/nvim%-treesitter\'.-)\n%-%- =+\n%-%- SECTION 10:'))
local pending, starts = {}, {}
vim.pack.add = function() end
package.loaded['nvim-treesitter'] = {
  install = function(language)
    return { await = function(_, callback)
      pending[#pending + 1] = { language = language, callback = callback }
    end }
  end,
  get_available = function() return { 'lua', 'python', 'c' } end,
  get_installed = function() return {} end,
}
vim.treesitter.language.add = function() return true end
vim.treesitter.start = function(buf, language)
  starts[#starts + 1] = { buf = buf, language = language }
end
vim.treesitter.query.get = function(language)
  return language == 'lua' and {} or nil
end
assert(loadstring('local gh = function(repo) return repo end\n' .. section))()

local indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
local foldexpr = 'v:lua.vim.treesitter.foldexpr()'
local function request(filetype)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].filetype = filetype
  vim.bo[buf].indentexpr = 'GetLuaIndent()'
  return buf, pending[#pending].callback
end
local function expect_folds(win)
  assert(vim.wo[win].foldmethod == 'expr', 'missing folds in target window')
  assert(vim.wo[win].foldexpr == foldexpr, 'missing fold expression')
end

local original, complete = request 'lua'
vim.api.nvim_set_current_buf(original)
local original_win = vim.api.nvim_get_current_win()
vim.cmd 'vsplit'
local second_win = vim.api.nvim_get_current_win()
vim.cmd 'vnew'
local unrelated = vim.api.nvim_get_current_buf()
vim.bo.indentexpr = 'UnrelatedIndent()'
vim.wo.foldmethod = 'manual'
vim.wo.foldexpr = '0'
vim.wo.foldlevel = 7
complete()
assert(starts[#starts].buf == original, 'highlighting targeted the wrong buffer')
assert(vim.bo[original].indentexpr == indentexpr, 'indentation missed the original buffer')
assert(vim.bo[unrelated].indentexpr == 'UnrelatedIndent()', 'changed unrelated indentation')
assert(vim.wo.foldmethod == 'manual' and vim.wo.foldexpr == '0', 'changed unrelated folding')
assert(vim.wo.foldlevel == 7, 'attachment reset the fold level')
expect_folds(original_win)
expect_folds(second_win)

-- A hidden buffer can finish installation and acquire folds when displayed later.
local hidden, finish_hidden = request 'lua'
finish_hidden()
assert(vim.bo[hidden].indentexpr == indentexpr)
vim.api.nvim_set_current_buf(hidden)
expect_folds(vim.api.nvim_get_current_win())

-- Stale callbacks must not start a parser or change indentation.
local changed, finish_changed = request 'lua'
vim.bo[changed].filetype = 'python'
local count = #starts
local changed_indentexpr = vim.bo[changed].indentexpr
finish_changed()
assert(#starts == count and vim.bo[changed].indentexpr == changed_indentexpr)
-- Nor should a previously attached buffer receive folds for its old language.
vim.bo[hidden].filetype = 'python'
vim.wo.foldmethod = 'manual'
vim.api.nvim_exec_autocmds('BufWinEnter', { buffer = hidden })
assert(vim.wo.foldmethod == 'manual')

local unloaded, finish_unloaded = request 'lua'
vim.api.nvim_buf_delete(unloaded, { unload = true })
count = #starts
finish_unloaded()
assert(#starts == count, 'attached an unloaded buffer')
local deleted, finish_deleted = request 'lua'
vim.api.nvim_buf_delete(deleted, { force = true })
count = #starts
finish_deleted()
assert(#starts == count, 'attached a deleted buffer')

-- A language without an indent query keeps its existing indentation expression.
local no_indent, finish_no_indent = request 'c'
finish_no_indent()
assert(vim.bo[no_indent].indentexpr == 'GetLuaIndent()')
print 'Tree-sitter regression tests passed'
