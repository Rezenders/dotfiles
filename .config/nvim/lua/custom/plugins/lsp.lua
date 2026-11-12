-- LSP setup is called from init.lua at the original Section 6 startup position.
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

function M.setup()
  -- Useful status updates for LSP.
  vim.pack.add { gh 'j-hui/fidget.nvim' }
  require('fidget').setup {
    notification = {
    },
  }

  --  This function gets run when an LSP attaches to a particular buffer.
  --    That is to say, every time a new file is opened that is associated with
  --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
  --    function will be executed to configure the current buffer
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
    callback = function(event)
      -- In this case, we create a function that lets us more easily define mappings specific
      -- for LSP related items. It sets the mode, buffer and description for us each time.
      local map = function(keys, func, desc, mode)
        mode = mode or 'n'
        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
      end

      -- Rename the variable under your cursor.
      --  Most Language Servers support renaming across files, etc.
      map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

      -- Execute a code action, usually your cursor needs to be on top of an error
      -- or a suggestion from your LSP for this to activate.
      map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

      -- WARN: This is not Goto Definition, this is Goto Declaration.
      --  For example, in C this would take you to the header.
      map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

      -- The following two autocommands are used to highlight references of the
      -- word under your cursor when your cursor rests there for a little while.
      --    See `:help CursorHold` for information about when this is executed
      --
      -- When you move your cursor, the highlights will be cleared (the second autocommand).
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client:supports_method('textDocument/documentHighlight', event.buf) then
        local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
        if #vim.api.nvim_get_autocmds { group = highlight_augroup, buffer = event.buf } == 0 then
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = function(args) vim.api.nvim_buf_call(args.buf, vim.lsp.buf.document_highlight) end,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = function(args) vim.api.nvim_buf_call(args.buf, vim.lsp.buf.clear_references) end,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            buffer = event.buf,
            group = highlight_augroup,
            callback = function(args)
              -- LspDetach fires before the departing client is removed from get_clients().
              for _, remaining in ipairs(vim.lsp.get_clients { bufnr = args.buf, method = 'textDocument/documentHighlight' }) do
                if remaining.id ~= args.data.client_id then return end
              end
              vim.api.nvim_buf_call(args.buf, vim.lsp.buf.clear_references)
              vim.api.nvim_clear_autocmds { group = highlight_augroup, buffer = args.buf }
            end,
          })
        end
      end

      -- The following code creates a keymap to toggle inlay hints in your
      -- code, if the language server you are using supports them
      --
      -- This may be unwanted, since they displace some of your code
      if client and client:supports_method('textDocument/inlayHint', event.buf) then
        map('<leader>ti', function()
          local filter = { bufnr = event.buf }
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
        end, '[T]oggle Inlay [H]ints')
      end
    end,
  })

  -- Enable the following language servers
  --  See `:help lsp-config` for information about keys and how to configure
  ---@type table<string, vim.lsp.Config>
  local servers = {
    clangd = {},
    cmake = {
      cmd = { vim.fn.expand('~/.local/bin/cmake-language-server') },
    },
    pyright = {},
    marksman = {}, -- Markdown headings, links, and document symbols
    bashls = {},
    jsonls = {},
    yamlls = {},
    ansiblels = {},
    docker_compose_language_service = {},
    ruff = {}, -- Python linting and code fixes alongside Pyright
    dockerls = {},
    -- texlab and ltex_plus are added below from custom.latex.lsp
    --
    -- Some languages (like rust) have entire language plugins that can be useful:
    --    https://github.com/mrcjkb/rustaceanvim
    --
    -- But for many setups, the LSP (`rust_analyzer`) will work just fine
    rust_analyzer = {},

    -- Special Lua Config, as recommended by neovim help docs
    lua_ls = {
      on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
        end

        local current_settings = client.config.settings --[[@as lspconfig.settings.lua_ls]]
        client.config.settings.Lua = vim.tbl_deep_extend('force', current_settings.Lua, {
          runtime = {
            version = 'LuaJIT',
            path = { 'lua/?.lua', 'lua/?/init.lua' },
          },
          workspace = {
            checkThirdParty = false,
            -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
            --  See https://github.com/neovim/nvim-lspconfig/issues/3189
            library = vim.api.nvim_get_runtime_file('', true),
          },
        })
      end,
      ---@type lspconfig.settings.lua_ls
      settings = {
        Lua = {
          format = { enable = false }, -- Disable formatting (formatting is done by stylua)
        },
      },
    },
  }
  -- LaTeX language servers (texlab, ltex_plus)
  servers = vim.tbl_extend('error', servers, require('custom.latex.lsp').servers())

  vim.pack.add {
    gh 'neovim/nvim-lspconfig',
    gh 'mason-org/mason.nvim',
    gh 'mason-org/mason-lspconfig.nvim',
    gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
    { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' },
  }

  -- Load Blink before enabling servers so their initialize requests advertise
  -- its completion capabilities. UI/snippet setup runs in custom.plugins.completion (section 8).
  vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities(nil, true) })

  -- Automatically install LSPs and related tools to stdpath for Neovim
  require('mason').setup {}

  -- Translates between nvim-lspconfig server names and mason.nvim package names (e.g. lua_ls <-> lua-language-server)
  require('mason-lspconfig').setup {
    automatic_enable = false,
  }

  -- Ensure the servers and tools above are installed
  --
  -- To check the current status of installed tools and/or manually install
  -- other tools, you can run
  --    :Mason
  --
  -- You can press `g?` for help in this menu.
  local ensure_installed = vim.tbl_filter(function(name)
    return name ~= 'cmake' -- Installed externally via Snap
  end, vim.tbl_keys(servers))
  vim.list_extend(ensure_installed, {
    'prettier', -- Markdown formatting
    'stylua', -- Lua formatting via Conform, not a separate language server
    'markdownlint', -- Markdown linting (nvim-lint)
  })

  require('mason-tool-installer').setup { ensure_installed = ensure_installed }

  require('custom.health').lsp_servers = vim.tbl_keys(servers)
  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end
end

return M
