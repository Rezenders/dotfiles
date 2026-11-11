-- Run from ~/.config/nvim: nvim --clean -l tests/file_autocmds.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local module = require 'custom.file_autocmds'
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local original = { uis = vim.api.nvim_list_uis, confirm = vim.fn.confirm, mkdir = vim.fn.mkdir }
local prompts = 0
local answer = 1
vim.api.nvim_list_uis = function() return { {} } end
vim.fn.confirm = function(_, _, default)
  assert(default == 2, 'directory creation must default to No')
  prompts = prompts + 1
  return answer
end

local function edit(path) vim.cmd('edit! ' .. vim.fn.fnameescape(path)) end

local function restore(buf, ft)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  if ft then vim.bo[buf].filetype = ft end
  vim.api.nvim_exec_autocmds('BufReadPost', { group = 'custom-file-conveniences', buffer = buf })
  vim.wait(20, function() return false end)
end

local ok, err = xpcall(function()
  module.setup()
  module.setup() -- Re-sourcing must not duplicate callbacks.
  assert(#vim.api.nvim_get_autocmds { group = 'custom-file-conveniences' } == 2)
  local file = root .. '/existing.txt'
  vim.fn.writefile({ 'first', 'second', 'third' }, file)
  edit(file)
  vim.wait(20, function() return false end)
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_mark(buf, '"', 2, 3, {})
  restore(buf)
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 3 }), 'restore valid mark')

  vim.api.nvim_buf_set_mark(buf, '"', 2, 99, {})
  restore(buf)
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 5 }), 'clamp old column')
  local get_mark = vim.api.nvim_buf_get_mark
  vim.api.nvim_buf_get_mark = function() return { 99, 0 } end
  restore(buf)
  vim.api.nvim_buf_get_mark = get_mark
  assert(vim.api.nvim_win_get_cursor(0)[1] == 1, 'ignore stale line')
  vim.api.nvim_buf_set_mark(buf, '"', 2, 0, {})

  for _, ft in ipairs { 'gitcommit', 'gitrebase', 'help' } do
    restore(buf, ft)
    assert(vim.api.nvim_win_get_cursor(0)[1] == 1, 'ignore ' .. ft)
  end
  vim.bo.filetype = ''
  vim.wo.diff = true
  restore(buf)
  assert(vim.api.nvim_win_get_cursor(0)[1] == 1, 'ignore diff')
  vim.wo.diff = false
  vim.bo.buftype = 'nofile'
  restore(buf)
  assert(vim.api.nvim_win_get_cursor(0)[1] == 1, 'ignore special buffers')
  vim.bo.buftype = ''

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_exec_autocmds('BufReadPost', { buffer = buf })
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  vim.wait(20, function() return false end)
  assert(vim.api.nvim_win_get_cursor(0)[1] == 3, 'preserve explicit navigation')

  edit(root .. '/accepted/deep/new.txt')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'saved' })
  vim.cmd.write()
  assert(vim.fn.readfile(root .. '/accepted/deep/new.txt')[1] == 'saved')
  assert(prompts == 1)
  vim.cmd.write()
  assert(prompts == 1, 'existing parents need no prompt')

  answer = 2
  edit(root .. '/declined/new.txt')
  local saved = pcall(vim.cmd.write)
  assert(not saved and vim.fn.isdirectory(root .. '/declined') == 0, 'decline aborts')
  assert(vim.fn.filereadable(root .. '/declined/new.txt') == 0)

  local before = prompts
  vim.api.nvim_list_uis = function() return {} end
  edit(root .. '/headless/new.txt')
  assert(not pcall(vim.cmd.write), 'headless normal write fails without prompting')
  assert(prompts == before and vim.fn.isdirectory(root .. '/headless') == 0)
  vim.cmd 'write!'
  assert(vim.fn.filereadable(root .. '/headless/new.txt') == 1, 'bang explicitly allows mkdir')
  assert(prompts == before)

  -- :write to another path must create that target's parent, not the buffer's.
  vim.cmd('write! ' .. vim.fn.fnameescape(root .. '/other/deep/output.txt'))
  assert(vim.fn.filereadable(root .. '/other/deep/output.txt') == 1)
  vim.cmd('saveas! ' .. vim.fn.fnameescape(root .. '/renamed/deep/output.txt'))
  assert(vim.fn.filereadable(root .. '/renamed/deep/output.txt') == 1)

  -- A URI write target from a normal local buffer must not create local dirs.
  local uri_mkdir = false
  vim.fn.mkdir = function()
    uri_mkdir = true
    error 'must not mkdir for URI targets'
  end
  pcall(vim.cmd, 'write! test-scheme://remote/not-a-local-file')
  vim.fn.mkdir = original.mkdir
  assert(not uri_mkdir, 'URI write targets must not attempt mkdir')
  assert(vim.fn.isdirectory(vim.fn.getcwd() .. '/test-scheme:') == 0)

  -- URI/special buffers must never prompt or mkdir, including forced writes.
  vim.cmd.enew { bang = true }
  vim.api.nvim_buf_set_name(0, 'test-scheme://remote/not-a-local-file')
  vim.api.nvim_exec_autocmds('BufWritePre', { pattern = 'test-scheme://remote/not-a-local-file' })
  vim.bo.buftype = 'nofile'
  vim.api.nvim_exec_autocmds('BufWritePre', { pattern = root .. '/special/new.txt' })
  assert(vim.fn.isdirectory(root .. '/special') == 0 and prompts == before)
  vim.bo.buftype = ''

  vim.api.nvim_list_uis = function() return { {} } end
  answer = 1
  edit(root .. '/failure/new.txt')
  vim.fn.mkdir = function() error 'permission denied (test)' end
  assert(not pcall(vim.cmd.write), 'mkdir failures must surface')
  assert(vim.fn.filereadable(root .. '/failure/new.txt') == 0)
  vim.fn.mkdir = original.mkdir

  -- Real startup: an explicit +line must win over a saved ShaDa mark.
  local shada = root .. '/test.shada'
  edit(file)
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  vim.api.nvim_buf_set_mark(0, '"', 3, 0, {})
  local old_shada = vim.o.shada
  vim.o.shada = "!,'100,<50,s10,h" -- Default ShaDa excludes /tmp, where this fixture lives.
  vim.cmd('wshada! ' .. vim.fn.fnameescape(shada))
  vim.o.shada = old_shada
  local bootstrap = root .. '/init.lua'
  vim.fn.writefile({
    ('vim.opt.runtimepath:prepend(%q)'):format(vim.fn.getcwd()),
    'require("custom.file_autocmds").setup()',
    'vim.api.nvim_create_autocmd("VimEnter", { callback = function() vim.schedule(function()',
    '  local expected = tonumber(vim.env.FILE_AUTOCMDS_EXPECTED)',
    '  if vim.api.nvim_win_get_cursor(0)[1] ~= expected then vim.cmd("cquit 1") end',
    '  vim.cmd("bwipeout!")',
    ('  vim.cmd(%q)'):format('edit +1 ' .. vim.fn.fnameescape(file)),
    '  vim.schedule(function()',
    '    if vim.api.nvim_win_get_cursor(0)[1] ~= 1 then vim.cmd("cquit 2") end',
    '    vim.cmd("qa!")',
    '  end)',
    'end) end })',
  }, bootstrap)
  for _, case in ipairs { { line = 3 }, { line = 1, jump = '+1' } } do
    local command = { vim.v.progpath, '--headless', '-u', bootstrap, '-i', shada }
    if case.jump then command[#command + 1] = case.jump end
    command[#command + 1] = file
    local result = vim
      .system(command, {
        text = true,
        timeout = 5000,
        env = { FILE_AUTOCMDS_EXPECTED = tostring(case.line) },
      })
      :wait()
    assert(result.code == 0, ('startup cursor %d: %s'):format(case.line, result.stderr or ''))
  end
end, debug.traceback)
vim.api.nvim_list_uis = original.uis
vim.fn.confirm = original.confirm
vim.fn.mkdir = original.mkdir
vim.cmd 'silent! %bwipeout!'
vim.fn.delete(root, 'rf')
assert(ok, err)
print 'file_autocmds: all tests passed'
