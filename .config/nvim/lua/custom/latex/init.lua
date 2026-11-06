-- LaTeX support: VimTeX, snippets, language servers and completion.
--
-- The pieces are wired up from init.lua at the points where load order matters:
--   require('custom.latex.lsp').servers()      -- merged into the LSP `servers` table
--   require('custom.latex.completion').setup() -- before blink.cmp is configured
--   require('custom.latex').setup()            -- after LuaSnip is loaded
-- Buffer-local options and keymaps live in after/ftplugin/tex.lua.
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

function M.setup()
  vim.pack.add {
    gh 'lervag/vimtex',
    gh 'iurimateus/luasnip-latex-snippets.nvim',
  }

  vim.g.vimtex_view_method = vim.g.vimtex_view_method or 'zathura_simple'

  -- Load mathematical LaTeX snippets
  require('luasnip-latex-snippets').setup {
    use_treesitter = false,
    allow_on_markdown = false,
  }
end

return M
