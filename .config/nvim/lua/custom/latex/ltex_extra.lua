-- Bind ltex_extra's scheduled work to the originating client and project.
-- Keep this in the config (not the plugin checkout) until upstream carries a fix.
local M = {}
local initialized = false
local directories = setmetatable({}, { __mode = 'k' })

local function dictionary_directory(client)
  if not directories[client] then
    -- Rootless clients keep the cwd from attach, not from a later callback.
    local root = client.root_dir or client.config.root_dir or vim.fn.getcwd()
    directories[client] = vim.fs.normalize(vim.fn.fnamemodify(root .. '/.ltex', ':p'))
  end
  return directories[client]
end

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

  local function filename(directory, kind, lang)
    return vim.fs.joinpath(directory, table.concat({ 'ltex', kind, lang, 'txt' }, '.'))
  end

  local function update(client, directory, kind, lang)
    if not client or client:is_stopped() then return end
    local settings = client.config.settings
    settings.ltex = settings.ltex or {}
    for _, key in ipairs(types) do
      settings.ltex[key] = settings.ltex[key] or {}
    end
    local path = filename(directory, kind, lang)
    settings.ltex[kind][lang] = fs.path_exist(path) and fs.readFile(path) or {}
    client:notify('workspace/didChangeConfiguration', { settings = settings })
  end

  -- Resolve both client and absolute storage BEFORE scheduling.
  commands.updateConfig = function(kind, lang, client)
    client = client or find_client()
    if not client then return end
    update(client, dictionary_directory(client), kind, lang)
  end
  commands.reload = function(langs, client)
    client = client or find_client()
    if not client then return end
    local directory = dictionary_directory(client)
    for _, lang in ipairs(langs or extra.opts.load_langs) do
      vim.schedule(function()
        for _, kind in ipairs(types) do
          update(client, directory, kind, lang)
        end
      end)
    end
  end

  local function handler(kind, argument)
    return function(command, context)
      local client = find_client(context)
      if not client or client:is_stopped() then return end
      local directory = dictionary_directory(client)
      for lang, entries in pairs(command.arguments[1][argument]) do
        if fs.check_dir(directory) then
          fs.writeFile(filename(directory, kind, lang), entries)
        end
        vim.schedule(function() update(client, directory, kind, lang) end)
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
