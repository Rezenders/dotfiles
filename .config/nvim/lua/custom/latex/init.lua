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

  -- Build into ./build by default; a project's .latexmkrc ($out_dir) takes priority.
  vim.g.vimtex_compiler_latexmk = vim.tbl_extend('keep', vim.g.vimtex_compiler_latexmk or {}, {
    out_dir = 'build',
  })

  -- Default engine when neither a project .latexmkrc nor a "% !TeX program" line sets one.
  vim.g.vimtex_compiler_latexmk_engines = vim.tbl_extend('keep', vim.g.vimtex_compiler_latexmk_engines or {}, {
    _ = '-lualatex',
  })

  -- Load mathematical LaTeX snippets
  require('luasnip-latex-snippets').setup {
    use_treesitter = false,
    allow_on_markdown = false,
  }
end

return M
