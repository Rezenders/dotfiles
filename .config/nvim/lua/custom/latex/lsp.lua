-- Language servers for LaTeX: TexLab (build, ChkTeX, formatting) and LTeX+ (grammar/spelling).
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

---@return table<string, vim.lsp.Config>
function M.servers()
  -- Client-side LTeX commands: dictionary, false positives, and rule disabling.
  vim.pack.add { gh 'barreiroleo/ltex_extra.nvim' }

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
