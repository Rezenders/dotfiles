-- Run from the config directory: nvim --clean -l tests/lsp_capabilities.lua
-- Exercise the actual LSP registration block without installing plugins/servers.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local source = table.concat(vim.fn.readfile 'init.lua', '\n')
assert(loadfile 'init.lua') -- Check the full configuration's Lua syntax too.
local registration = assert(source:match("(  vim%.pack%.add {\n    gh 'neovim/nvim%-lspconfig'.-)\nend\n\n%-%- Markdown formatting"))
local blink_path = vim.fn.stdpath 'data' .. '/site/pack/core/opt/blink.cmp'
assert(vim.fn.isdirectory(blink_path) == 1, 'Install blink.cmp via vim.pack to run these tests')
local added_blink = false
---@diagnostic disable-next-line: duplicate-set-field
vim.pack.add = function(plugins)
  for _, plugin in ipairs(plugins) do
    if type(plugin) == 'table' and plugin.src == 'https://github.com/saghen/blink.cmp' then
      added_blink = true
      vim.opt.runtimepath:prepend(blink_path)
    end
  end
end
for _, name in ipairs { 'mason', 'mason-lspconfig', 'mason-tool-installer' } do
  package.loaded[name] = { setup = function() end }
end
local servers = {
  guide_test = { cmd = { 'unused' }, settings = { keep = true } },
  guide_override = {
    cmd = { 'unused' },
    capabilities = { textDocument = { completion = { completionItem = { preselectSupport = true } } } },
  },
}
local enabled = 0
---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.enable = function(name)
  enabled = enabled + 1
  assert(added_blink, 'Blink must be loaded before enabling servers')
  local capabilities = vim.lsp.config[name].capabilities
  local item = capabilities.textDocument.completion.completionItem
  assert(item.snippetSupport == true, 'Snippet support must remain advertised')
  assert(item.commitCharactersSupport == false, 'Commit characters must match Blink')
  assert(item.preselectSupport == (name == 'guide_override'), 'Server overrides must take precedence')
  assert(capabilities.workspace.configuration == true, 'Non-completion Neovim defaults must be retained')
end
local env = setmetatable({
  servers = servers,
  gh = function(repo) return 'https://github.com/' .. repo end,
}, { __index = _G })
local chunk = assert(loadstring(registration))
setfenv(chunk, env)()
assert(enabled == 2, 'All configured servers must be enabled')
local health_servers = require('kickstart.health').lsp_servers
assert(#health_servers == 2 and vim.list_contains(health_servers, 'guide_test')
  and vim.list_contains(health_servers, 'guide_override'), 'Health must check the configured servers')
assert(vim.lsp.config.guide_test.settings.keep == true, 'Server settings must be retained')
local blink = require 'blink.cmp'
assert(vim.deep_equal(vim.lsp.config.guide_test.capabilities, blink.get_lsp_capabilities(nil, true)),
  'Default server capabilities must match Blink plus Neovim defaults')
local _, registrations = source:gsub("gh 'saghen/blink%.cmp'", '')
assert(registrations == 1, 'Blink should be registered exactly once')
assert(source:find("require('blink.cmp').setup", source:find('%-%- SECTION 8:', 1)),
  'Blink UI setup must remain in the completion section')
print 'LSP capability regression tests passed'
