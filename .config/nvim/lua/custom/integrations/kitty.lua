-- kitty configuration, explicitly initialized from init.lua.
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

function M.setup()
  -- [[ Scrollback browsing ]]
  vim.pack.add { gh 'mikesmithgh/kitty-scrollback.nvim' }
  require('kitty-scrollback').setup({
    {
      visual_selection_highlight_mode = 'kitty',
    },
  })

  vim.pack.add({
    { src = 'https://github.com/folke/snacks.nvim' },
  })
  require('snacks').setup({
    image = {
      enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= 'true',

      doc = {
        enabled = true,
        inline = true,
        float = true,
        max_width = 80,
        max_height = 40,
        conceal = function(_, kind)
          return kind == 'math'
        end,
      },

      math = {
        enabled = true,
      },
    },
  })
  vim.keymap.set('n', '<leader>ip', function()
    Snacks.image.hover()
  end, { desc = 'Preview image or equation' })

  -- [[ Smart Splits ]]
  vim.pack.add {
    { src = 'https://github.com/smart-splits-nvim/smart-splits.nvim' },
    { src = 'https://github.com/smart-splits-nvim/backend-kitty' },
  }

  require('smart-splits').setup {
    mux = {
      backend = 'smart-splits-backend-kitty',
    },
    move = {
      at_edge = 'stop',
    },
    resize = {
      amount = 3,
    },
  }

  local splits = require('smart-splits')

  -- Navigation
  vim.keymap.set('n', '<C-h>', splits.move_cursor_left)
  vim.keymap.set('n', '<C-j>', splits.move_cursor_down)
  vim.keymap.set('n', '<C-k>', splits.move_cursor_up)
  vim.keymap.set('n', '<C-l>', splits.move_cursor_right)

  -- Resizing
  vim.keymap.set('n', '<A-h>', splits.resize_left)
  vim.keymap.set('n', '<A-j>', splits.resize_down)
  vim.keymap.set('n', '<A-k>', splits.resize_up)
  vim.keymap.set('n', '<A-l>', splits.resize_right)

  local function kitty_split(direction)
    vim.fn.jobstart({
      'kitten', '@', 'launch',
      '--type=window',
      '--location=' .. direction,
      '--cwd=' .. vim.fn.getcwd(),
    })
  end
  -- Side by side
  vim.keymap.set('n', '<leader>tv', function()
    kitty_split('vsplit')
  end, { desc = 'Kitty vertical split' })

  -- Top and bottom
  vim.keymap.set('n', '<leader>th', function()
    kitty_split('hsplit')
  end, { desc = 'Kitty horizontal split' })

  -- [[ Kitty docks ]]
  require('custom.kitty_docks').setup()
end

return M
