-- VimTeX completion source for blink.cmp (via blink.compat + cmp-vimtex).
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

-- Must run before require('blink.cmp').setup().
function M.setup()
  vim.pack.add {
    gh 'micangl/cmp-vimtex',
    {
      src = gh 'saghen/blink.compat',
      version = vim.version.range '2.*',
    },
  }

  require('blink.compat').setup {}
  require('cmp_vimtex').setup {
    -- Use VimTeX's bibliography data instead of cmp-vimtex's faulty async parser.
    bibtex_parser = { enabled = false },
  }
end

-- Merged into blink.cmp's `sources` table.
M.blink_sources = {
  -- Add VimTeX completion only for LaTeX files
  per_filetype = {
    tex = { 'vimtex', inherit_defaults = true },
  },
  -- Configure the VimTeX completion provider
  providers = {
    vimtex = {
      name = 'vimtex',
      module = 'blink.compat.source',
      min_keyword_length = 0,
    },
  },
}

return M
