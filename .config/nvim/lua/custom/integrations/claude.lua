-- claude configuration, explicitly initialized from init.lua.
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

function M.setup()
  vim.pack.add {
    gh 'coder/claudecode.nvim',
  }

  require('claudecode').setup({
    terminal = {
      provider = 'none',
      split_side = 'right',
      split_width_percentage = 0.35,
    },
  })

  -- Keybindings
  -- Claude runs in a kitty pane (`claude --ide`); provider 'none' cannot
  -- toggle or focus it, so pane switching/zoom is handled by kitty.
  -- Pi runs in a kitty dock pane via make_dock_launcher inheriting Neovim's environment.
  vim.keymap.set('n', '<leader>ab', '<cmd>ClaudeCodeAdd %<CR>',
    { desc = 'Add current buffer to Claude' })

  vim.keymap.set('v', '<leader>as', '<cmd>ClaudeCodeSend<CR>',
    { desc = 'Send selection to Claude' })

  vim.keymap.set('n', '<leader>aa', '<cmd>ClaudeCodeDiffAccept<CR>',
    { desc = 'Accept Claude diff' })

  vim.keymap.set('n', '<leader>ad', '<cmd>ClaudeCodeDiffDeny<CR>',
    { desc = 'Reject Claude diff' })
end

return M
