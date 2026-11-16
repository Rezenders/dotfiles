-- Follow the terminal's actual background, with a bounded desktop fallback.
local M = {}

-- TermResponse OSC strings omit their BEL/ST terminator. Match Neovim's native
-- luminance test, accepting the 1-4 digit RGB(A) components used by terminals.
function M.background_from_response(response)
  local r, g, b = response:match '^\027%]11;rgb:(%x+)/(%x+)/(%x+)$'
  if not r then
    local alpha
    r, g, b, alpha = response:match '^\027%]11;rgba:(%x+)/(%x+)/(%x+)/(%x+)$'
    if not alpha or #alpha > 4 then return end
  end
  if not r or #r > 4 or #g > 4 or #b > 4 then return end
  local function component(value) return tonumber(value, 16) / tonumber(string.rep('f', #value), 16) end
  return 0.299 * component(r) + 0.587 * component(g) + 0.114 * component(b) < 0.5 and 'dark' or 'light'
end

function M.setup(personal)
  local group = vim.api.nvim_create_augroup('custom-appearance', { clear = true })
  local applied
  local function apply(background)
    if applied == background then return end
    applied = background
    if vim.o.background ~= background then vim.o.background = background end
    -- Use the family entry point: Kanagawa's background map selects dragon/lotus.
    -- ColorScheme callbacks continue to own diagnostic/gutter highlight polish.
    vim.cmd.colorscheme(personal and 'kanagawa' or 'gruvbox')
  end

  -- The TUI can detect background before user config runs. Don't replace a
  -- known terminal value with the desktop preference (especially over SSH).
  local info = vim.api.nvim_get_option_info2('background', {})
  if #vim.api.nvim_list_uis() > 0 and info.was_set then
    apply(vim.o.background)
  else
    apply(require('custom.runtime').system_is_dark() and 'dark' or 'light')
  end

  -- Neovim's TUI already subscribes to mode 2031 theme notifications and queries
  -- OSC 11 after changes/resume. Keep our own listener because Gruvbox explicitly
  -- sets 'background', which disables the native auto-detection callback.
  vim.tty.request('', { group = group, timeout = 0 }, function(response)
    local background = M.background_from_response(response)
    if background then apply(background) end
  end)
  local function query()
    if #vim.api.nvim_list_uis() > 0 then vim.api.nvim_ui_send '\027]11;?\007' end
  end
  vim.api.nvim_create_autocmd('UIEnter', { group = group, callback = query })
  query() -- asynchronous; unsupported terminals never block startup
end

return M
