-- kitty configuration, explicitly initialized from init.lua.
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

function M.setup()
  -- [[ Scrollback browsing ]]
  vim.pack.add { gh 'mikesmithgh/kitty-scrollback.nvim' }
  require('kitty-scrollback').setup {}

  -- [[ Image support ]]
  vim.pack.add {
    { src = 'https://github.com/3rd/image.nvim' },
  }

  -- Avoid image rendering conflicts in kitty-scrollback's Neovim instance.
  if vim.env.KITTY_SCROLLBACK_NVIM ~= 'true' then
    require('image').setup {
      backend = 'kitty',
      processor = 'magick_cli',

      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = false,
          only_render_image_at_cursor = false,
          filetypes = { 'markdown' },
        },
      },

      max_width = 100,
      max_height = 30,
      max_width_window_percentage = 100,
      max_height_window_percentage = 50,
    }
  end
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
