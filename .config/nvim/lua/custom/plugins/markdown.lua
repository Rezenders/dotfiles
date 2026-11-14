-- markdown configuration, explicitly initialized from init.lua.
local M = {}

function M.setup()
  vim.pack.add({
    'https://github.com/MeanderingProgrammer/render-markdown.nvim',
  })

  require('render-markdown').setup({
    enabled = false, -- Start with ordinary Markdown

    file_types = { 'markdown' },

    -- Snacks handles mathematical expressions
    latex = {
      enabled = false,
    },

    -- Keep the rendering relatively minimal
    -- heading = {
    --   sign = false,
    -- },
    --
    -- code = {
    --   sign = false,
    -- },
  })

  vim.keymap.set('n', '<leader>mp', function()
    require('render-markdown').toggle()
  end, { desc = 'Toggle Markdown rendering' })

  vim.keymap.set('n', '<leader>ms', '<cmd>RenderMarkdown preview<cr>',
    { desc = 'Markdown side-by-side preview' })
  end

return M
