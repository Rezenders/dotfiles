-- file explorer configuration, explicitly initialized from init.lua.
local M = {}

function M.setup()
  vim.pack.add({
    {
      src = 'https://github.com/nvim-neo-tree/neo-tree.nvim',
      version = vim.version.range('3')
    },
    -- dependencies
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/MunifTanjim/nui.nvim",
  })

  vim.keymap.set('n', '\\', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })

  require('neo-tree').setup {
    popup_border_style = 'rounded',
    filesystem = {
      window = {
        mappings = {
          ['\\'] = 'close_window',
          ['Y'] = function(state)
             local node = state.tree:get_node()
             local path = vim.fn.fnamemodify(node:get_id(), ':.')
             vim.fn.setreg('+', path)
             vim.notify('Copied: ' .. path)
          end,
        },
      },
    },
    source_selector = {
      winbar = true,
      statusline = false,
      content_layout = 'center',
      tabs_layout = 'equal',
      show_separator_on_edge = false,

      sources = {
        { source = 'filesystem', display_name = ' 󰉓 Files ' },
        { source = 'buffers',    display_name = ' 󰈚 Buffers ' },
        { source = 'git_status', display_name = ' 󰊢 Git ' },
      },

      separator = {
        left = ' ',
        right = ' ',
      },
    }
  }
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'neo-tree-popup',
    callback = function()
      vim.opt_local.list = false
      vim.opt_local.cursorline = false
    end,
  })
end

return M
