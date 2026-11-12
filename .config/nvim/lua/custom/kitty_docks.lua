-- Kitty dock management: toggle side "dock" windows for Yazi, Claude, and Pi.
local M = {}

-- Identify docks by application and owning Neovim window.
local dock_helper = vim.fn.stdpath 'config' .. '/kitty/dock_toggle.py'
local dock_busy = {}

function M.make_dock_launcher(cmd)
  local owner = vim.env.KITTY_WINDOW_ID or tostring(vim.fn.getpid())
  local script_path = string.format('/tmp/nvim-dock-%s-%s.sh', owner, cmd)
  local f = io.open(script_path, 'w')
  if not f then return cmd end

  f:write '#!/bin/sh\n'
  for k, v in pairs(vim.fn.environ()) do
    if k ~= '_' and k ~= 'KITTY_WINDOW_ID' and k:match '^[%a_][%w_]*$' then f:write(string.format("export %s='%s'\n", k, v:gsub("'", "'\\''"))) end
  end
  local exe = vim.fn.exepath(cmd)
  if exe == '' then exe = cmd end
  f:write(string.format('exec %s "$@"\n', exe))
  f:close()

  vim.fn.setfperm(script_path, 'rwx------')
  return script_path
end

function M.kitty_dock(kind, edge, size, launch_env, cmd)
  local owner = vim.env.KITTY_WINDOW_ID
  if not owner then
    vim.notify('Neovim must be running inside Kitty', vim.log.levels.ERROR)
    return
  end
  if dock_busy[kind] then return end
  dock_busy[kind] = true
  local function done() dock_busy[kind] = nil end
  local function run(args, callback) require('custom.runtime').run_dock(args, callback, done) end
  local tag = kind .. '-' .. owner
  run({ 'ls' }, function(output)
    local ok, windows = pcall(vim.json.decode, output)
    if not ok then
      done()
      vim.notify('Could not decode Kitty window list', vim.log.levels.ERROR)
      return
    end
    local existing
    for _, os_window in ipairs(windows) do
      for _, tab in ipairs(os_window.tabs) do
        for _, window in ipairs(tab.windows) do
          if (window.user_vars or {}).nvim_dock == tag then existing = window.id end
        end
      end
    end
    if existing then
      if kind == 'yazi' then
        run({ 'close-window', '--match=id:' .. existing }, done)
      else
        run({ 'kitten', dock_helper, owner, tostring(existing) }, done)
      end
      return
    end

    -- Only launching Claude requires its integration server to be running.
    local env = launch_env()
    if not env then
      done()
      return
    end
    local args = {
      'launch',
      '--type=tab-dock',
      '--match=window_id:' .. owner,
      '--dock-edge=' .. edge,
      '--dock-size=' .. size,
      '--cwd=' .. vim.fn.getcwd(),
      '--var=nvim_dock=' .. tag,
    }
    -- if kind == 'yazi' then
    --   args[#args + 1] = '--keep-focus'
    -- end
    for key, value in pairs(env) do
      args[#args + 1] = '--env=' .. key .. '=' .. value
    end
    local launch_cmd = type(cmd) == 'function' and cmd() or (cmd or kind)
    if type(launch_cmd) == 'table' then
      vim.list_extend(args, launch_cmd)
    else
      args[#args + 1] = launch_cmd
    end
    run(args, done)
  end)
end

function M.setup()
  vim.keymap.set('n', '<leader>ty', function()
    M.kitty_dock('yazi', 'left', '20%', function()
      if vim.v.servername == '' then
        vim.notify('Neovim server is not running', vim.log.levels.ERROR)
        return
      end
      return {
        NVIM_SERVER = vim.v.servername,
        NVIM_KITTY_WINDOW_ID = vim.env.KITTY_WINDOW_ID,
      }
    end)
  end, { desc = 'Open/close Yazi dock' })

  vim.keymap.set('n', '<leader>tcr', function()
    M.kitty_dock('claude', 'right', '25%', function()
      local port = require('claudecode').state.port
      if not port then
        vim.notify('claudecode.nvim server is not running (:ClaudeCodeStart)', vim.log.levels.ERROR)
        return
      end
      return {
        CLAUDE_CODE_SSE_PORT = tostring(port),
        ENABLE_IDE_INTEGRATION = 'true',
      }
    end)
  end, { desc = 'Toggle Claude dock right' })

  vim.keymap.set('n', '<leader>tcl', function()
    M.kitty_dock('claude', 'left', '25%', function()
      local port = require('claudecode').state.port
      if not port then
        vim.notify('claudecode.nvim server is not running (:ClaudeCodeStart)', vim.log.levels.ERROR)
        return
      end
      return {
        CLAUDE_CODE_SSE_PORT = tostring(port),
        ENABLE_IDE_INTEGRATION = 'true',
      }
    end)
  end, { desc = 'Toggle Claude dock left' })

  vim.keymap.set('n', '<leader>tpr', function()
    M.kitty_dock('pi', 'right', '25%', function() return {} end, function() return M.make_dock_launcher 'pi' end)
  end, { desc = 'Toggle Pi dock right' })

  vim.keymap.set('n', '<leader>tpl', function()
    M.kitty_dock('pi', 'left', '25%', function() return {} end, function() return M.make_dock_launcher 'pi' end)
  end, { desc = 'Toggle Pi dock left' })
end

return M
