-- keymaps configuration, explicitly initialized from init.lua.
local M = {}

function M.setup()
  -- Native gx treats the colon in SCP-style addresses as a filename separator.
  local default_gx = vim.fn.maparg('gx', 'n', false, true).callback
  vim.keymap.set('n', 'gx', function()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1
    local offset = 1
    while true do
      local first, last, repo = line:find('git@github%.com:([%w_.-]+/[%w_.-]+)', offset)
      if not first then break end
      if col >= first and col <= last then
        local _, err = vim.ui.open('https://github.com/' .. repo:gsub('%.git$', ''))
        if err then vim.notify(err, vim.log.levels.ERROR) end
        return
      end
      offset = last + 1
    end
    default_gx()
  end, { desc = 'Open URL or GitHub SSH repository under cursor' })

  -- Toggle undo tree
  vim.keymap.set('n', '<leader>u', '<cmd>Undotree<CR>', {
    desc = 'Toggle undo tree',
  })

  -- [[ Basic Keymaps ]]
  --  See `:help vim.keymap.set()`

  -- Clear highlights on search when pressing <Esc> in normal mode
  --  See `:help hlsearch`
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Diagnostic Config & Keymaps
  --  See `:help vim.diagnostic.Opts`
  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    -- Mark problems by underlining the flagged range (every severity); the wavy style
    -- and colours come from polish_ui() in custom.plugins.ui.
    underline = true,

    -- No inline messages: read them with [d / ]d (float below) or <C-w>d on the word.
    virtual_text = false,
    virtual_lines = false,

    -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }
      end,
    },
    signs = {
      text = {
         [vim.diagnostic.severity.ERROR] = '󰅚 ',
         [vim.diagnostic.severity.WARN]  = '󰀪 ',
         [vim.diagnostic.severity.INFO]  = '󰋽 ',
         [vim.diagnostic.severity.HINT]  = '󰌶 ',
      },
    },
  }

  vim.keymap.set('n', '<leader>q', function()
    vim.diagnostic.setloclist {
      format = function(diagnostic)
        -- Filter both push and pull LTeX+ namespaces, not in-buffer diagnostics.
        local namespace = vim.diagnostic.get_namespace(diagnostic.namespace)
        if namespace.name:match '^nvim%.lsp%.ltex_plus%.' then return nil end
        return diagnostic.message
      end,
    }
  end, { desc = 'Open diagnostic location list (excluding LTeX+)' })

  -- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
  -- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
  -- is not what someone will guess without a bit more experience.
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- TIP: Disable arrow keys in normal mode
  -- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
  -- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
  -- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
  -- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

  -- Keybinds to make split navigation easier.
  --  Use CTRL+<hjkl> to switch between windows
  --
  --  See `:help wincmd` for a list of all window commands
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- Toggle comments with Ctrl + /
  vim.keymap.set('n', '<C-/>', 'gcc', { remap = true, desc = 'Toggle comment' })
  vim.keymap.set('x', '<C-/>', 'gc', { remap = true, desc = 'Toggle comment' })

  vim.keymap.set('n', '<leader>x', function()
    require('mini.bufremove').delete(0, false)
  end, { desc = 'Close current buffer (preserve layout)' })
end

return M
