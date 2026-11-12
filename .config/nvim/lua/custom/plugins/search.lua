-- search configuration, explicitly initialized from init.lua.
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

function M.setup()
  -- fzf-lua uses the external fzf binary. Press <F1> in a picker for help.
  vim.pack.add { gh 'ibhagwan/fzf-lua' }
  local fzf = require 'fzf-lua'
  fzf.setup {
    -- Derive fzf's own colors from the active colorscheme's highlight groups.
    fzf_colors = true,
    -- fzf's list scrollbar leaves stray '│' marks in the float as results stream in.
    fzf_opts = { ['--no-scrollbar'] = true },
    keymap = {
      builtin = {
        ["<C-d>"] = "preview-page-down",
        ["<C-u>"] = "preview-page-up",
      },
    },
    winopts = {
      border = 'rounded',
      width = 0.9,
      height = 0.9,
      cursorline = true,
      -- path_shorten = 2,
      title_pos = 'left',
      preview = {
        layout = 'flex',
        flip_columns = 135, -- anything under 135 cols switches to vertical split
        horizontal = 'right:45%', -- preview on right only in genuinely wide panes
        vertical = 'down:40%', -- preview on bottom in medium/narrow panes

        title_pos = 'left',
        scrollbar = 'float',
      },
    },
    files = {
      formatter = 'path.dirname_first',
    },
  }
  fzf.register_ui_select()

  vim.keymap.set('n', '<leader>sh', fzf.helptags, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sk', fzf.keymaps, { desc = '[S]earch [K]eymaps' })
  vim.keymap.set('n', '<leader>sf', fzf.files, { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>ss', fzf.builtin, { desc = '[S]earch [S]elect picker' })
  vim.keymap.set('n', '<leader>sw', fzf.grep_cword, { desc = '[S]earch current [W]ord' })
  vim.keymap.set('x', '<leader>sw', fzf.grep_visual, { desc = '[S]earch selected [W]ords' })
  vim.keymap.set('n', '<leader>sg', fzf.live_grep, { desc = '[S]earch by [G]rep' })
  vim.keymap.set('n', '<leader>sd', fzf.diagnostics_workspace, { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sr', fzf.resume, { desc = '[S]earch [R]esume' })
  vim.keymap.set('n', '<leader>s.', fzf.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
  vim.keymap.set('n', '<leader>sc', fzf.commands, { desc = '[S]earch [C]ommands' })

  -- buffer navigation
  vim.keymap.set('n', '<leader><leader>', fzf.buffers, { desc = '[ ] Find existing buffers' })
  vim.keymap.set('n', '<leader>bb', '<C-^>', {
    desc = 'Switch to last buffer visited'
  })
  vim.keymap.set('n', '<S-l>', '<cmd>bnext<CR>', {
    desc = 'Next buffer',
  })
  vim.keymap.set('n', '<S-h>', '<cmd>bprevious<CR>', {
    desc = 'Previous buffer',
  })

  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('fzf-lua-lsp-attach', { clear = true }),
    callback = function(event)
      local buf = event.buf
      vim.keymap.set('n', 'grr', fzf.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
      vim.keymap.set('n', 'gri', fzf.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })
      vim.keymap.set('n', 'grd', fzf.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })
      vim.keymap.set('n', 'gO', fzf.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })
      vim.keymap.set('n', 'gW', fzf.lsp_live_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })
      vim.keymap.set('n', 'grt', fzf.lsp_typedefs, { buffer = buf, desc = '[G]oto [T]ype Definition' })
    end,
  })

  vim.keymap.set('n', '<leader>/', function()
    fzf.blines { previewer = false }
  end, { desc = '[/] Fuzzily search in current buffer' })

  vim.keymap.set('n', '<leader>s/', function()
    -- Search the on-disk contents of listed file buffers, not the whole project.
    local paths = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' then
        local name = vim.api.nvim_buf_get_name(buf)
        if name ~= '' and vim.fn.filereadable(name) == 1 then
          paths[#paths + 1] = name
        end
      end
    end
    -- Avoid opening an empty picker when no listed file buffers are searchable.
    if #paths == 0 then
      vim.notify('No open files to search', vim.log.levels.INFO)
      return
    end
    fzf.live_grep { search_paths = paths, prompt = 'Grep Open Files> ' }
  end, { desc = '[S]earch [/] in Open Files' })

  vim.keymap.set('n', '<leader>sn', function()
    fzf.files { cwd = vim.fn.stdpath 'config', cmd = 'rg --files --follow --glob !.git' }
  end, { desc = '[S]earch [N]eovim files' })
end

return M
