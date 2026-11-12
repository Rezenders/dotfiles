-- options configuration, explicitly initialized from init.lua.
local M = {}

function M.setup()
  vim.loader.enable()

  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '
  vim.g.have_nerd_font = true

  vim.o.number = true
  vim.o.relativenumber = false

  -- Enable mouse mode, can be useful for resizing splits for example!
  vim.o.mouse = 'a'

  -- Don't show the mode, since it's already in the status line
  vim.o.showmode = false
  vim.o.laststatus = 3
  vim.o.cmdheight = 0
  -- Experimental message/cmdline UI: avoids "Press ENTER" prompts with cmdheight=0.
  require('vim._core.ui2').enable {}

  -- Unified floating-window style
  vim.o.winborder = 'rounded'
  vim.o.pumborder = 'rounded'

  -- Sync clipboard between OS and Neovim.
  --  Schedule the setting after `UiEnter` because it can increase startup-time.
  --  Remove this option if you want your OS clipboard to remain independent.
  --  See `:help 'clipboard'`
  vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

  vim.o.linebreak = true
  vim.o.breakindent = true

  -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
  vim.o.ignorecase = true
  vim.o.smartcase = true
  -- Keep signcolumn on by default
  vim.o.signcolumn = 'yes'

  -- Decrease update time
  vim.o.updatetime = 250

  -- Decrease mapped sequence wait time
  vim.o.timeoutlen = 300

  -- Configure how new splits should be opened
  vim.o.splitright = true
  vim.o.splitbelow = true

  -- Sets how neovim will display certain whitespace characters in the editor.
  --  See `:help 'list'`
  --  and `:help 'listchars'`
  --
  --  Notice listchars is set using `vim.opt` instead of `vim.o`.
  --  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
  --   See `:help lua-options`
  --   and `:help lua-guide-options`
  vim.o.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
  -- Preview substitutions live, as you type!
  vim.o.inccommand = 'split'

  -- Show which line your cursor is on
  vim.o.cursorline = true

  -- Minimal number of screen lines to keep above and below the cursor.
  vim.o.scrolloff = 12

  -- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
  -- instead raise a dialog asking if you wish to save the current file(s)
  -- See `:help 'confirm'`
  vim.o.confirm = true

  vim.o.exrc = true

  -- START Optimizations for light mode

  -- Uses 24-bit hex definitions colors
  vim.opt.termguicolors = true
  -- END

  -- vim.o.pumblend = 10 -- transparency for popup menu / completions (0-100)
  -- vim.o.winblend = 10  -- keep at 0 if you prefer crisp contrast, or 5-10 for subtle float glass effect

  -- Native Neovim undo tree
  vim.cmd.packadd('nvim.undotree')

  -- Persist undo history across Neovim sessions
  vim.o.undofile = true

  -- Maximum number of undo changes
  vim.o.undolevels = 10000


end

return M
