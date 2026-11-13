-- Editing behavior and source annotations.
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

function M.setup()
  vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
  require('guess-indent').setup {
    filetype_exclude = {
        'netrw',
        'tutor',
        'tex',
        'plaintex',
    },
  }

  -- Highlight todo, notes, etc in comments
  vim.pack.add {
    gh 'nvim-lua/plenary.nvim', -- todo-comments search dependency, independent of Git setup.
    gh 'folke/todo-comments.nvim',
  }
  require('todo-comments').setup { signs = false }

  -- [[ mini.nvim ]]
  --  A collection of various small independent plugins/modules
  vim.pack.add { gh 'nvim-mini/mini.nvim' }

  -- Better Around/Inside textobjects
  --
  -- Examples:
  --  - va)  - [V]isually select [A]round [)]paren
  --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
  --  - ci'  - [C]hange [I]nside [']quote
  local ai = require 'mini.ai'

  ai.setup {
    -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
    mappings = {
      around_next = 'aa',
      inside_next = 'ii',
    },
    n_lines = 500,
    custom_textobjects = {
      d = ai.gen_spec.treesitter {
        a = '@do.outer',
        i = '@do.inner',
      },
    },
  }

  -- Add/delete/replace surroundings (brackets, quotes, etc.)
  --
  -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
  -- - sd'   - [S]urround [D]elete [']quotes
  -- - sr)'  - [S]urround [R]eplace [)] [']
  require('mini.surround').setup()

  -- Delete buffers without closing their windows; unsaved changes require confirmation.
  require('mini.bufremove').setup()
  -- gS toggles the argument list/table under the cursor between one and many lines.
  require('mini.splitjoin').setup()
  -- Keep Alt-h/j/k/l available for Kitty-aware split resizing.
  require('mini.move').setup {
    mappings = {
      left = '<leader>mh',
      right = '<leader>ml',
      down = '<leader>mj',
      up = '<leader>mk',
      line_left = '<leader>mh',
      line_right = '<leader>ml',
      line_down = '<leader>mj',
      line_up = '<leader>mk',
    },
    options = { reindent_linewise = true },
  }

  vim.pack.add { gh 'windwp/nvim-autopairs' }
  require('nvim-autopairs').setup {}
end

return M
