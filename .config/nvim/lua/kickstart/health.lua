-- Environment checks for the integrations enabled by this configuration.
local M = {}

local function executable(exe, purpose)
  local found = vim.fn.executable(exe) == 1
  local message = ('%s: %s'):format(purpose, exe)
  if found then
    vim.health.ok(message)
  else
    vim.health.warn(message .. ' not found; install it or disable the integration')
  end
  return found
end

local function check_version()
  if vim.fn.has 'nvim-0.12' == 1 and vim.pack and vim.lsp.config and vim.lsp.enable and vim.system then
    vim.health.ok('Neovim ' .. tostring(vim.version()) .. ' provides the required pack/LSP/process APIs')
  else
    vim.health.error 'Neovim 0.12+ with vim.pack, vim.lsp.config/enable and vim.system is required; use the configured nightly'
  end
end

local function check_tools()
  vim.health.start 'Core, Markdown and images'
  for _, exe in ipairs { 'git', 'make', 'unzip', 'rg', 'cc', 'fzf', 'node', 'npm', 'prettier', 'markdownlint', 'magick' } do
    executable(exe, 'Configured tool')
  end
  vim.health.info 'Mason tools are checked on Neovim’s PATH after Mason setup. Run :Mason to install missing managed tools.'
  vim.health.info 'Markdown: Prettier uses project configuration; the column guide uses markdownlint MD013. Keep those project policies aligned.'

  vim.health.start 'LaTeX and Go debugging (optional per workflow)'
  for _, exe in ipairs { 'latexmk', 'pdflatex', 'chktex', 'latexindent', 'zathura', 'go', 'dlv' } do
    executable(exe, 'Workflow tool')
  end
end

local function check_lsp()
  vim.health.start 'Configured language server commands'
  -- Populated from the actual server table, including custom LaTeX servers.
  if not M.lsp_servers then
    vim.health.warn 'Server configuration has not been registered; run this check after normal init.lua setup'
    return
  end
  for _, name in ipairs(M.lsp_servers) do
    local ok, config = pcall(function() return vim.lsp.config[name] end)
    if not ok or not config then
      vim.health.warn(name .. ': could not resolve LSP configuration; check :LspLog and nvim-lspconfig')
    elseif type(config.cmd) == 'table' and type(config.cmd[1]) == 'string' then
      executable(config.cmd[1], name)
    elseif type(config.cmd) == 'function' then
      -- These providers prefer project-local binaries, then fall back to PATH.
      local fallback = { jsonls = 'vscode-json-language-server', yamlls = 'yaml-language-server' }
      if fallback[name] then
        executable(fallback[name], name .. ' (PATH fallback; provider may use a project-local binary)')
      else
        vim.health.info(name .. ': command is a function; executable must be checked by its provider')
      end
    else
      vim.health.warn(name .. ': no command configured')
    end
  end
end

local function check_kitty()
  vim.health.start 'Kitty, docks and remote control'
  executable('kitty', 'Kitty terminal')
  local kitten = executable('kitten', 'Kitty remote control')
  for _, exe in ipairs { 'yazi', 'claude', 'pi' } do
    executable(exe, 'Optional dock application')
  end
  local helper = vim.fn.stdpath 'config' .. '/kitty/dock_toggle.py'
  if vim.fn.filereadable(helper) == 1 then
    vim.health.ok('Dock helper: ' .. helper)
  else
    vim.health.warn('Missing dock helper: ' .. helper)
  end
  if not vim.env.KITTY_WINDOW_ID then
    vim.health.warn 'Not running inside Kitty (KITTY_WINDOW_ID missing); docks and Kitty graphics are unavailable'
    return
  end
  if not kitten then return end
  -- Read-only and bounded. Do not launch or move windows during a health check.
  local ok, result = pcall(function() return vim.system({ 'kitten', '@', 'ls' }, { text = true, timeout = 2000 }):wait() end)
  if ok and type(result) == 'table' and result.code == 0 then
    vim.health.ok 'Kitty remote control is reachable'
  else
    local reason = type(result) == 'table' and (result.stderr or ('exit ' .. tostring(result.code))) or tostring(result or 'no result (timeout)')
    vim.health.warn('Kitty remote control failed: ' .. reason .. '; enable allow_remote_control and verify KITTY_LISTEN_ON/socket permissions')
  end
  vim.health.info 'Docks require a Kitty release supporting launch --type=tab-dock; use :checkhealth kitty-scrollback for scrollback checks.'
end

local function check_pi()
  vim.health.start 'Optional local Pi fork'
  local path = vim.fn.expand '~/git/pi-nvim'
  if vim.fn.isdirectory(path .. '/lua/pi-nvim') == 1 or vim.fn.filereadable(path .. '/lua/pi-nvim.lua') == 1 then
    vim.health.ok('Local Pi Lua entrypoint: ' .. path)
  else
    vim.health.warn('Local Pi checkout is missing: ' .. path .. '; bootstrap instructions and revision are in INTEGRATIONS.md')
  end
  if (package.loaded['custom.runtime'] or {}).pi_ready then
    vim.health.info 'Pi module loaded. Use :PiPing to test live session connectivity; health checks do not send prompts.'
  else
    vim.health.warn 'Pi integration is not loaded; inspect startup warnings and INTEGRATIONS.md for compatibility details'
  end
end

function M.check()
  vim.health.start 'kickstart.nvim'
  vim.health.info 'Workflow-specific warnings are optional: install tools only for integrations you use.'
  vim.health.info('System Information: ' .. vim.inspect(vim.uv.os_uname()))
  check_version()
  check_tools()
  check_lsp()
  check_kitty()
  check_pi()
end

return M
