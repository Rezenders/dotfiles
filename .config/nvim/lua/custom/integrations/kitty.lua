-- kitty configuration, explicitly initialized from init.lua.
local M = {}
local snacks_doc_filtered = false

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
  -- Snacks has no per-buffer math switch. Filter discovery results so both
  -- inline and hover previews keep images, but leave TeX equations to VimTeX.
  if not snacks_doc_filtered then
    local doc = require 'snacks.image.doc'
    local find = doc.find
    doc.find = function(buf, cb, opts)
      return find(buf, function(matches)
        if not vim.api.nvim_buf_is_valid(buf) then return cb({}) end
        if vim.bo[buf].filetype == 'tex' then
          matches = vim.tbl_filter(function(match) return match.type ~= 'math' end, matches)
        end
        cb(matches)
      end, opts)
    end
    snacks_doc_filtered = true
  end
  require('snacks').setup({
    dashboard = {
      enabled = true,
      width = 60,
      preset = {
        -- Keep Snacks' default ASCII-art header.
        keys = {
          { icon = ' ', key = 'f', desc = 'Find File', action = function() require('fzf-lua').files() end },
          { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
          { icon = ' ', key = 'g', desc = 'Find Text', action = function() require('fzf-lua').live_grep() end },
          { icon = ' ', key = 'r', desc = 'Recent Files', action = function() require('fzf-lua').oldfiles() end },
          {
            icon = ' ',
            key = 'c',
            desc = 'Neovim Config',
            action = function() require('fzf-lua').files { cwd = vim.fn.stdpath 'config' } end,
          },
          { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
        },
      },
      sections = {
        { section = 'header', padding = 1 },
        { section = 'keys', gap = 1, padding = 1 },
        { section = 'recent_files', title = 'Recent Files', icon = ' ', limit = 5, indent = 2, padding = 1 },
        { section = 'projects', title = 'Projects', icon = ' ', limit = 4, indent = 2, padding = 1, session = false },
      },
    },
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
