-- Language servers for LaTeX: TexLab (build, ChkTeX, formatting) and LTeX+ (grammar/spelling).
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

---@return table<string, vim.lsp.Config>
function M.servers()
  -- Client-side LTeX commands: dictionary, false positives, and rule disabling.
  vim.pack.add { 'https://github.com/barreiroleo/ltex_extra.nvim' }

  return {
    texlab = {
      settings = {
        texlab = {
          build = {
            onSave = false,
          },
          -- Run chktex on open/save. honours the project's .chktexrc
          chktex = {
            onOpenAndSave = true,
            onEdit = false,
          },
          -- Use latexindent for formatting
          latexFormatter = 'latexindent',

          latexindent = {
            modifyLineBreaks = false,
          },
        },
      },
    },
    -- Grammar and spelling checking
    ltex_plus = {
      filetypes = { 'tex', 'plaintex', 'markdown' },
      -- Class and style files are LaTeX code, not prose: do not grammar-check them.
      -- Neovim attaches the server only when root_dir calls on_dir.
      root_dir = function(bufnr, on_dir)
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name:match '%.cls$' or name:match '%.sty$' then return end
        on_dir(vim.fs.root(bufnr, { '.git' }) or vim.fs.dirname(name))
      end,
      -- Bind deferred dictionary updates to the attached LTeX client.
      on_attach = require('custom.latex.ltex_extra').on_attach,
      settings = {
        ltex = {
          language = 'en-US',
        },
      },
    },
  }
end

return M
