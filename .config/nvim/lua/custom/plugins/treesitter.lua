-- Parser installation and Treesitter attachment; called at the original Section 9 position.
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

function M.setup()
  vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

  -- Ensure basic parsers are installed
  local parsers = {
      'bash',
      'c',
      'diff',
      'html',
      'lua',
      'luadoc',
      'markdown',
      'markdown_inline',
      'query',
      'vim',
      'vimdoc'
  }
  require('nvim-treesitter').install(parsers)

  vim.o.foldlevel = 99       -- Don't fold everything by default when opening a file
  vim.o.foldlevelstart = 99  -- Start with all folds open

  local attached_languages = {}

  local function buffer_has_language(buf, language)
    return vim.api.nvim_buf_is_loaded(buf)
      and vim.treesitter.language.get_lang(vim.bo[buf].filetype) == language
  end

  local function treesitter_folds(buf)
    local language = attached_languages[buf]
    if not language or not buffer_has_language(buf, language) then return end
    local ts_foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      -- Respect a fold method chosen elsewhere (modeline, ftplugin, :set): only take
      -- over the default 'manual', or re-apply our own treesitter expr.
      local wo = vim.wo[win][0]
      if wo.foldmethod == 'manual' or (wo.foldmethod == 'expr' and wo.foldexpr == ts_foldexpr) then
        -- Set only the window-local value, not the default for future buffers.
        wo.foldexpr = ts_foldexpr
        wo.foldmethod = 'expr'
      end
    end
  end

  vim.api.nvim_create_autocmd('BufWinEnter', {
    callback = function(args) treesitter_folds(args.buf) end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    callback = function(args) attached_languages[args.buf] = nil end,
  })

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    -- Installation may finish after the buffer is unloaded or its filetype changes.
    if not buffer_has_language(buf, language) then return end

    -- Check if a parser exists and load it
    if not vim.treesitter.language.add(language) then return end

    -- Enable syntax highlighting and other treesitter features
    vim.treesitter.start(buf, language)

    -- Folding belongs to each window displaying this buffer, including later ones.
    attached_languages[buf] = language
    treesitter_folds(buf)

    -- Check if treesitter indentation is available for this language, and if so enable it
    -- in case there is no indent query, the indentexpr will fallback to the vim's built in one
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil

    -- Enable treesitter based indentation
    if has_indent_query then vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match

      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end
      -- VimTeX needs its own regex syntax (math detection, conceal, live preview);
      -- starting treesitter on tex buffers turns that syntax off.
      if language == 'latex' then return end

      local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

      if vim.tbl_contains(installed_parsers, language) then
        -- Enable the parser if it is already installed
        treesitter_try_attach(buf, language)
      elseif vim.tbl_contains(available_parsers, language) then
        -- If a parser is available in `nvim-treesitter`, auto-install it and enable it after the installation is done
        require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
      else
        -- Try to enable treesitter features in case the parser exists but is not available from `nvim-treesitter`
        treesitter_try_attach(buf, language)
      end
    end,
  })
end

return M
