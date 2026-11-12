-- autocmds configuration, explicitly initialized from init.lua.
local M = {}

function M.setup()
  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`

  require('custom.file_autocmds').setup()

  -- Highlight when yanking (copying) text
  --  Try it with `yap` in normal mode
  --  See `:help vim.hl.on_yank()`
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.hl_op() end,
  })

  local excluded_filetypes = {
    markdown = true,
    rmd = true,
    quarto = true,
    diff = true,
    gitcommit = true,
  }

  local function trim_trailing_whitespace()
    local view = vim.fn.winsaveview()

    vim.cmd([[silent! keeppatterns keepjumps %s/\s\+$//e]])

    vim.fn.winrestview(view)
  end

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup(
      "trim-trailing-whitespace",
      { clear = true }
    ),

    pattern = "*",

    callback = function(args)
      local buf = args.buf

      -- Ignore special and binary buffers
      if vim.bo[buf].buftype ~= "" or vim.bo[buf].binary then
        return
      end

      -- Ignore filetypes where whitespace may be significant
      if excluded_filetypes[vim.bo[buf].filetype] then
        return
      end

      trim_trailing_whitespace()
    end,
  })
end

return M
