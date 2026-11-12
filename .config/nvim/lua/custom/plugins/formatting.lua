-- One manual, asynchronous formatting workflow; never format on save.
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

function M.format()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= '' or not vim.bo[buf].modifiable then
    vim.notify('Formatting: current buffer is not an editable file buffer', vim.log.levels.WARN)
    return
  end

  -- Preserve TexLab's latexindent settings, including modifyLineBreaks=false.
  -- Do not fall back to LTeX+ or another attached server.
  if vim.bo[buf].filetype == 'tex' or vim.bo[buf].filetype == 'plaintex' then
    if #vim.lsp.get_clients { bufnr = buf, name = 'texlab', method = 'textDocument/formatting' } == 0 then
      vim.notify('Formatting: no formatting-capable TexLab attached; check :LspInfo and latexindent', vim.log.levels.WARN)
      return
    end
    vim.lsp.buf.format {
      bufnr = buf,
      async = true,
      filter = function(client) return client.name == 'texlab' end,
    }
    return
  end

  local conform = require 'conform'
  if #conform.list_formatters(buf) == 0 then
    local filetype = vim.bo[buf].filetype ~= '' and vim.bo[buf].filetype or 'this filetype'
    vim.notify('Formatting: no formatter available for ' .. filetype .. '; check :ConformInfo', vim.log.levels.WARN)
    return
  end
  conform.format { bufnr = buf, async = true }
end

function M.setup()
  vim.pack.add { gh 'stevearc/conform.nvim' }

  require('conform').setup {
    default_format_opts = { lsp_format = 'never' }, -- Only explicitly selected formatters.
    notify_no_formatters = true, -- Report configured but unavailable formatter commands.
    formatters_by_ft = {
      markdown = { 'prettier' }, -- Project Prettier settings, no personal CLI overrides.
      lua = { 'stylua' },
      python = { 'ruff_format' }, -- Formatting only, not Ruff lint fixes/import organization.
      ruby = { 'rubocop' }, -- Conform's safe autocorrection (-a), not unsafe corrections (-A).
    },
    formatters = {
      rubocop = function(buf)
        local filename = vim.api.nvim_buf_get_name(buf)
        local dirname = filename ~= '' and vim.fs.dirname(filename) or vim.fn.getcwd()
        local root = vim.fs.root(dirname, { 'Gemfile' })
        if root then
          local binstub = vim.fs.joinpath(root, 'bin', 'rubocop')
          if vim.fn.executable(binstub) == 1 then return { command = binstub, cwd = function() return root end } end
          -- Never silently substitute a global RuboCop for a project's bundled version.
          return { command = 'bundle', prepend_args = { 'exec', 'rubocop' }, cwd = function() return root end }
        end
        return { command = require('conform.util').find_executable({ 'bin/rubocop' }, 'rubocop') }
      end,
    },
  }

  vim.keymap.set('n', '<leader>cf', M.format, { desc = 'Format current buffer' })
  vim.keymap.set('n', '<leader>mf', M.format, { desc = 'Format current buffer (alias)' })
end

return M
