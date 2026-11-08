-- Visual guide only: never changes textwidth, wrapping, or lint policy.
local M = {}
local cache = {}
local debounce = 0
local refresh_scheduled = false
local helper = vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)), 'markdown_line_length.cjs')

local function valid_limit(value) return type(value) == 'number' and value > 0 and value < math.huge and value == math.floor(value) end

local function markdown_context(win)
  local ok, lint = pcall(require, 'lint')
  if not ok then return end
  local active = false
  for _, name in ipairs(lint.linters_by_ft.markdown or {}) do
    if name == 'markdownlint' then active = true end
  end
  if not active then return end
  local linter = lint.linters.markdownlint
  -- Custom commands/arguments need their own resolver; never guess their policy.
  if type(linter) ~= 'table' or type(linter.cmd) ~= 'string' then return end
  if not vim.deep_equal(linter.args, { '--stdin' }) then return end
  local executable = vim.fn.exepath(linter.cmd)
  if executable == '' or vim.fn.executable 'node' ~= 1 then return end
  local tab = vim.api.nvim_win_get_tabpage(win)
  local cwd = vim.fn.getcwd(vim.fn.getwininfo(win)[1].winnr, vim.api.nvim_tabpage_get_number(tab))
  return linter.cwd or cwd, executable
end

local function apply(win, limit)
  if vim.api.nvim_win_is_valid(win) then vim.wo[win].colorcolumn = valid_limit(limit) and tostring(limit + 1) or '' end
end

function M.refresh()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local bo = vim.bo[buf]
    if bo.buftype ~= '' or vim.api.nvim_win_get_config(win).relative ~= '' then
      apply(win, false)
    else
      local override = vim.b[buf].line_length_limit
      if override == false or valid_limit(override) then
        apply(win, override)
      elseif bo.filetype ~= 'markdown' then
        apply(win, 80)
      else
        vim.api.nvim_win_call(win, function()
          local cwd, executable = markdown_context(win)
          if not cwd then
            apply(win, 80)
            return
          end
          local key = cwd .. '\0' .. executable
          local entry = cache[key]
          if not entry then
            entry = { limit = 80, revision = 0, dirty = true }
            cache[key] = entry
          end
          if entry.dirty and not entry.pending and not refresh_scheduled then
            entry.dirty = false
            entry.pending = true
            local revision = entry.revision
            vim.system({ 'node', helper, executable }, { cwd = cwd, text = true }, function(result)
              vim.schedule(function()
                entry.pending = false
                if revision ~= entry.revision then
                  M.refresh()
                  return
                end
                entry.error = nil
                if result.code == 0 then
                  local ok, decoded = pcall(vim.json.decode, result.stdout)
                  if ok and type(decoded) == 'table' and (decoded.limit == false or valid_limit(decoded.limit)) then
                    entry.limit = decoded.limit
                    entry.dependencies = {}
                    for _, path in ipairs(decoded.dependencies or {}) do
                      entry.dependencies[vim.fs.normalize(path)] = true
                    end
                  else
                    entry.error = true
                  end
                else
                  entry.error = true
                end
                if entry.error then
                  entry.dependencies = nil
                  vim.notify(
                    'Line-length guide: could not read markdownlint configuration; keeping the previous guide (80 if unresolved). Run :LineLengthRefresh to retry.',
                    vim.log.levels.WARN
                  )
                end
                M.refresh()
              end)
            end)
          end
          apply(win, entry.limit)
        end)
      end
    end
  end
end

local function invalidate(path, delayed)
  local changed = false
  for _, entry in pairs(cache) do
    -- Until a lookup succeeds, its dependencies are unknown; be conservative.
    if not path or not entry.dependencies or entry.dependencies[path] or entry.dependencies[vim.fn.resolve(path)] then
      entry.revision = entry.revision + 1
      entry.dirty = true
      changed = true
    end
  end
  if not changed then return end
  debounce = debounce + 1
  local token = debounce
  refresh_scheduled = delayed or false
  if delayed then
    vim.defer_fn(function()
      if token ~= debounce then return end
      refresh_scheduled = false
      M.refresh()
    end, 100)
  else
    M.refresh()
  end
end

function M.invalidate()
  invalidate(nil, false)
  M.refresh()
end

function M.setup()
  local group = vim.api.nvim_create_augroup('custom-line-length', { clear = true })
  vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter', 'WinEnter', 'BufEnter' }, {
    group = group,
    callback = M.refresh,
  })
  -- Includes inherited config files with arbitrary names, not just .markdownlint.*.
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    callback = function(event)
      local path = event.file ~= '' and vim.fn.fnamemodify(event.file, ':p') or ''
      if path ~= '' then invalidate(vim.fs.normalize(path), true) end
    end,
  })
  -- External edits cannot be attributed to a particular dependency.
  vim.api.nvim_create_autocmd('FocusGained', {
    group = group,
    callback = function() invalidate(nil, true) end,
  })
  vim.api.nvim_create_autocmd('DirChanged', { group = group, callback = M.refresh })
  vim.api.nvim_create_user_command('LineLengthRefresh', M.invalidate, { force = true, desc = 'Reload line-length guides' })
  M.refresh()
end

return M
