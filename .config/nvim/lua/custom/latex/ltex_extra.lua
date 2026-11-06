-- Compatibility fix for ltex_extra's current-buffer lookup in scheduled work.
-- Keep this in the config (not the plugin checkout) until upstream carries a fix.
local M = {}
local initialized = false

local function find_client(context)
  if context and context.client_id then
    return vim.lsp.get_client_by_id(context.client_id)
  end
  local bufnr = context and context.bufnr or vim.api.nvim_get_current_buf()
  for _, name in ipairs { 'ltex', 'ltex_plus' } do
    local client = vim.lsp.get_clients({ bufnr = bufnr, name = name })[1]
    if client then return client end
  end
end

local function setup()
  local extra = require('ltex_extra')
  -- We perform the initial load below, using the client from on_attach.
  extra.setup { load_langs = { 'en-US' }, path = '.ltex', init_check = false }

  local commands = require('ltex_extra.commands-lsp')
  local fs = require('ltex_extra.utils.fs')
  local types = { 'dictionary', 'disabledRules', 'hiddenFalsePositives' }

  local function update(client, kind, lang)
    if not client or client:is_stopped() then return end
    local settings = client.config.settings
    settings.ltex = settings.ltex or {}
    for _, key in ipairs(types) do
      settings.ltex[key] = settings.ltex[key] or {}
    end
    settings.ltex[kind][lang] = fs.loadFile(kind, lang)
    client:notify('workspace/didChangeConfiguration', { settings = settings })
  end

  -- Resolve the client BEFORE scheduling, never from a later current buffer.
  commands.updateConfig = function(kind, lang, client)
    update(client or find_client(), kind, lang)
  end
  commands.reload = function(langs, client)
    client = client or find_client()
    if not client then return end
    for _, lang in ipairs(langs or extra.opts.load_langs) do
      vim.schedule(function()
        for _, kind in ipairs(types) do
          update(client, kind, lang)
        end
      end)
    end
  end

  local function handler(kind, argument)
    return function(command, context)
      local client = find_client(context)
      if not client or client:is_stopped() then return end
      for lang, entries in pairs(command.arguments[1][argument]) do
        fs.exportFile(kind, lang, entries)
        vim.schedule(function() update(client, kind, lang) end)
      end
    end
  end

  commands.addToDictionary = handler('dictionary', 'words')
  commands.disableRules = handler('disabledRules', 'ruleIds')
  commands.hideFalsePositives = handler('hiddenFalsePositives', 'falsePositives')
  -- setup() registered the original function values; replace those too.
  vim.lsp.commands['_ltex.addToDictionary'] = commands.addToDictionary
  vim.lsp.commands['_ltex.disableRules'] = commands.disableRules
  vim.lsp.commands['_ltex.hideFalsePositives'] = commands.hideFalsePositives
  initialized = true
end

function M.on_attach(client)
  if not initialized then setup() end
  require('ltex_extra.commands-lsp').reload(nil, client)
end

return M
