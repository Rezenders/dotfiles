-- Bounded, optional integrations: failures must not interrupt editor setup.
local M = {}

function M.system_is_dark()
  -- Headless/remote sessions need no desktop query. Light is the fallback.
  if
    #vim.api.nvim_list_uis() == 0
    or vim.env.SSH_CONNECTION
    or vim.env.SSH_TTY
    or not (vim.env.DISPLAY or vim.env.WAYLAND_DISPLAY)
    or vim.fn.executable 'gdbus' ~= 1
  then
    return false
  end
  local ok, result = pcall(
    function()
      return vim
        .system({
          'gdbus',
          'call',
          '--session',
          '--dest',
          'org.freedesktop.portal.Desktop',
          '--object-path',
          '/org/freedesktop/portal/desktop',
          '--method',
          'org.freedesktop.portal.Settings.Read',
          'org.freedesktop.appearance',
          'color-scheme',
        }, { text = true, timeout = 300 })
        :wait()
    end
  )
  return ok and type(result) == 'table' and result.code == 0 and tonumber((result.stdout or ''):match 'uint32%s+(%d+)') == 1
end

-- callback failures are included: a failed dock launch must remain retryable.
function M.run_dock(args, callback, done)
  local settled, timer, process = false, nil, nil
  local function report(message)
    done()
    vim.notify('Kitty dock: ' .. tostring(message), vim.log.levels.ERROR)
  end
  local function settle()
    if settled then return false end
    settled = true
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    return true
  end
  -- vim.system's async timeout only sends TERM. Release busy independently,
  -- even if the process ignores TERM or inherited pipes never close.
  timer = vim.defer_fn(function()
    if not settle() then return end
    if process then pcall(process.kill, process, 9) end
    report 'command timed out after 5 seconds'
  end, 5000)
  local ok, result_or_error = pcall(
    vim.system,
    vim.list_extend({ 'kitten', '@' }, args),
    { text = true, timeout = 5000 },
    vim.schedule_wrap(function(result)
      -- A late response must not launch a dock or clear a newer toggle's flag.
      if not settle() then return end
      if type(result) ~= 'table' or result.code ~= 0 then
        report(
          type(result) == 'table' and (result.stderr ~= '' and result.stderr or ('command failed (exit ' .. tostring(result.code) .. ')'))
            or 'command returned no result'
        )
        return
      end
      local success, message = pcall(callback, result.stdout)
      if not success then report(message) end
    end)
  )
  if ok then
    process = result_or_error
  elseif settle() then
    report(result_or_error)
  end
end

function M.setup_pi()
  M.pi_ready = false
  local path = vim.fn.expand '~/git/pi-nvim'
  if vim.fn.isdirectory(path .. '/lua/pi-nvim') ~= 1 and vim.fn.filereadable(path .. '/lua/pi-nvim.lua') ~= 1 then
    vim.notify('Pi integration disabled: missing checkout at ' .. path .. ' (see INTEGRATIONS.md)', vim.log.levels.WARN)
    return
  end
  vim.opt.runtimepath:prepend(path)
  local ok, pi = pcall(function()
    local plugin = require 'pi-nvim'
    plugin.setup { socket_path = nil, set_default_keymaps = true }
    for _, method in ipairs { 'append_selection', 'append_selection_prompt', 'append_file', 'append_buffer' } do
      assert(type(plugin[method]) == 'function', 'pi-nvim is missing ' .. method)
    end
    return plugin
  end)
  if not ok then
    vim.opt.runtimepath:remove(path)
    vim.notify('Pi integration disabled: ' .. tostring(pi) .. ' (see INTEGRATIONS.md)', vim.log.levels.WARN)
    return
  end
  M.pi_ready = true
  return pi
end

return M
