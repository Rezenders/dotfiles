-- markdown configuration, explicitly initialized from init.lua.
local M = {}

function M.setup()
  vim.pack.add({
    'https://github.com/OXY2DEV/markview.nvim',
  })

  require('markview').setup({})

  -- Toggle Markdown rendering
  vim.keymap.set('n', '<leader>mp', '<cmd>Markview<cr>',
    { desc = 'Toggle Markdown preview' })

  -- Toggle side-by-side Markdown preview
  vim.keymap.set('n', '<leader>ms', '<cmd>Markview splitToggle<cr>',
    { desc = 'Toggle Markdown split preview' })
end

return M
