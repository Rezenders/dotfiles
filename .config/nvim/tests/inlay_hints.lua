-- Run from the config directory: nvim --clean -l tests/inlay_hints.lua
-- Load the actual LspAttach configuration without installing plugins or servers.
local source = table.concat(vim.fn.readfile 'init.lua', '\n')
local attach = assert(source:match("(  vim%.api%.nvim_create_autocmd%('LspAttach', {\n    group = vim%.api%.nvim_create_augroup%('kickstart%-lsp%-attach'.-)\n\n  %-%- Enable the following language servers"))
local client_id = 123
---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.get_client_by_id = function(id)
  assert(id == client_id, 'unexpected client')
  return {
    supports_method = function(_, method)
      return method == 'textDocument/inlayHint'
    end,
  }
end
assert(loadstring(attach))()

local first = vim.api.nvim_create_buf(true, false)
local second = vim.api.nvim_create_buf(true, false)
local function configured_toggle(buf)
  vim.api.nvim_exec_autocmds('LspAttach', {
    group = 'kickstart-lsp-attach',
    buffer = buf,
    data = { client_id = client_id },
  })
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
    if mapping.desc == 'LSP: [T]oggle Inlay [H]ints' then
      assert(type(mapping.callback) == 'function', 'missing configured buffer-local toggle callback')
      return mapping.callback
    end
  end
  error('LspAttach did not configure the inlay hint toggle')
end
local toggles = { [first] = configured_toggle(first), [second] = configured_toggle(second) }
local hints = vim.lsp.inlay_hint

-- Exercise both mappings with the unset, enabled, and disabled global defaults.
-- Keep the unrelated buffer current to detect accidental use of bufnr=0 as well.
for _, global_mode in ipairs { 'default', 'enabled', 'disabled' } do
  if global_mode ~= 'default' then
    hints.enable(global_mode == 'enabled')
  end
  local global_enabled = hints.is_enabled()
  for _, target in ipairs { first, second } do
    local other = target == first and second or first
    vim.api.nvim_set_current_buf(other)
    for _, other_enabled in ipairs { false, true } do
      hints.enable(false, { bufnr = target })
      hints.enable(other_enabled, { bufnr = other })
      local other_before = hints.is_enabled { bufnr = other }
      -- Neovim 0.13's explicit global false gates even locally enabled hints.
      for _, expected in ipairs { global_mode ~= 'disabled', false } do
        toggles[target]()
        assert(hints.is_enabled { bufnr = target } == expected, 'target buffer did not toggle')
        assert(hints.is_enabled { bufnr = other } == other_before, 'toggle changed unrelated buffer hints')
        assert(hints.is_enabled() == global_enabled, 'toggle changed the global hint default')
      end
    end
  end
end
print 'Inlay hint regression tests passed'
