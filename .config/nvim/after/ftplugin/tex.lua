-- Buffer-local settings for LaTeX buffers (runs after VimTeX's ftplugin).

vim.keymap.set('n', '<leader>lf', function()
  vim.lsp.buf.format {
    async = true,
    filter = function(client) return client.name == 'texlab' end,
  }
end, { buffer = 0, desc = 'Format LaTeX document' })

-- Use LTeX+ for spelling and grammar instead of duplicate built-in highlights.
vim.opt_local.spell = false

-- Line wrapping
vim.opt_local.wrap = true
vim.opt_local.linebreak = true

-- show math symbols as unicode
vim.opt_local.conceallevel = 2
vim.opt_local.concealcursor = ''

-- LaTeX indentation: 2 spaces
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2
vim.opt_local.softtabstop = 2
