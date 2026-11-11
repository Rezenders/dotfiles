-- Small file-buffer conveniences; no plugins or filesystem work on startup.
local M = {}

local function file_buffer(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' and vim.bo[buf].modifiable and not vim.api.nvim_buf_get_name(buf):match '^%a[%w+.-]*:'
end

local function startup_jump()
  for _, arg in ipairs(vim.v.argv) do
    -- Startup commands, sessions, quickfix and tags own the initial position.
    if arg:match '^%+' or arg:match '^%-c' or arg:match '^%-%-cmd' or arg:match '^%-S' or arg:match '^%-q' or arg:match '^%-t' then return true end
  end
  return false
end

function M.setup()
  local group = vim.api.nvim_create_augroup('custom-file-conveniences', { clear = true })
  local initial_jump = startup_jump()
  local excluded = { gitcommit = true, gitrebase = true, help = true }

  vim.api.nvim_create_autocmd('BufReadPost', {
    group = group,
    desc = 'Restore last editing position without overriding explicit jumps',
    callback = function(args)
      if vim.v.vim_did_enter == 0 and initial_jump then return end
      local buf, win = args.buf, vim.api.nvim_get_current_win()
      if not file_buffer(buf) or vim.api.nvim_win_get_buf(win) ~= buf or vim.wo[win].diff then return end
      -- FileType detection may run after this handler during initial startup.
      local ft = vim.bo[buf].filetype
      if ft == '' then ft = vim.filetype.match { buf = buf } end
      if excluded[ft] then return end
      local cursor = vim.api.nvim_win_get_cursor(win)
      if cursor[1] ~= 1 or cursor[2] ~= 0 then return end
      local mark = vim.api.nvim_buf_get_mark(buf, '"')
      if mark[1] < 1 or mark[1] > vim.api.nvim_buf_line_count(buf) then return end
      -- Synchronous restoration runs BEFORE :edit +cmd, including an explicit
      -- jump to line 1. Deferring it could mistake that jump for an untouched cursor.
      local line = vim.api.nvim_buf_get_lines(buf, mark[1] - 1, mark[1], false)[1]
      pcall(vim.api.nvim_win_set_cursor, win, { mark[1], math.min(mark[2], math.max(#line - 1, 0)) })
    end,
  })

  vim.api.nvim_create_autocmd('BufWritePre', {
    group = group,
    desc = 'Offer to create missing parent directories for real files',
    callback = function(args)
      if not file_buffer(args.buf) then return end
      -- Use the write target, including :write other/path and :saveas targets.
      local path = args.match
      if path == '' or path:match '^%a[%w+.-]*:' then return end
      local parent = vim.fn.fnamemodify(path, ':p:h')
      if vim.fn.isdirectory(parent) == 1 then return end
      local force = vim.v.cmdbang == 1
      if not force then
        -- Headless/automated writes never block on a confirmation dialog.
        if #vim.api.nvim_list_uis() == 0 then error('Missing parent directory: ' .. parent .. ' (use :write! to create it explicitly)', 0) end
        if vim.fn.confirm('Create parent directory?\n' .. parent, '&Yes\n&No', 2) ~= 1 then error('Write canceled: parent directory was not created', 0) end
      end
      local ok, result = pcall(vim.fn.mkdir, parent, 'p')
      if not ok or (result ~= 1 and vim.fn.isdirectory(parent) ~= 1) then
        error('Could not create parent directory: ' .. parent .. (ok and '' or ('\n' .. tostring(result))), 0)
      end
    end,
  })
end

return M
