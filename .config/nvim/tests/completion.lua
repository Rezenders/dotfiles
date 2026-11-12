-- Run from the config directory: nvim --clean -l tests/completion.lua
-- Exercise completion and the real LaTeX bridge without installing plugins.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
assert(loadfile 'init.lua')
local init = table.concat(vim.fn.readfile 'init.lua', '\n')
local function position(call) return assert(init:find(call, 1, true), 'Missing startup call: ' .. call) end
assert(position("require('custom.plugins.lsp').setup()") < position("require('custom.plugins.completion').setup()"))
assert(position("require('custom.plugins.completion').setup()") < position("require('custom.plugins.treesitter').setup()"))
assert(position("require('custom.plugins.treesitter').setup()") < position("require('custom.latex').setup()"))

local events, added, options = {}, {}, {}
local function record(name) events[#events + 1] = name end
---@diagnostic disable-next-line: duplicate-set-field
vim.pack.add = function(plugins)
  for _, spec in ipairs(plugins) do
    local src = type(spec) == 'table' and spec.src or spec
    added[src:match('([^/]+)$')] = spec
  end
end
for _, name in ipairs { 'luasnip', 'blink.compat', 'cmp_vimtex', 'blink.cmp' } do
  package.loaded[name] = { setup = function(config)
    record(name)
    options[name] = config
  end }
end
package.loaded['luasnip.loaders.from_vscode'] = { lazy_load = function() record('friendly-snippets') end }
local completion = require 'custom.plugins.completion'
assert(#events == 0 and next(added) == nil, 'Requiring the module must not initialize plugins')
completion.setup()
assert(vim.deep_equal(events, { 'luasnip', 'friendly-snippets', 'blink.compat', 'cmp_vimtex', 'blink.cmp' }),
  'LuaSnip/snippets and LaTeX bridge must initialize before Blink UI')
assert(added.LuaSnip and added['friendly-snippets'] and added['cmp-vimtex'] and added['blink.compat'])
assert(tostring(added.LuaSnip.version) == tostring(vim.version.range '2.*'))
assert(not added['blink.cmp'], 'Blink must remain registered by LSP, not completion')
assert(vim.deep_equal(options.luasnip, { enable_autosnippets = true }))
assert(vim.deep_equal(options.cmp_vimtex, { bibtex_parser = { enabled = false } }))
local blink = options['blink.cmp']
assert(vim.deep_equal(blink.keymap, { preset = 'default' }))
assert(blink.appearance.nerd_font_variant == 'mono')
assert(vim.deep_equal(blink.completion.documentation, { auto_show = true, auto_show_delay_ms = 500 }))
assert(vim.deep_equal(blink.completion.menu.draw.treesitter, { 'lsp' }))
assert(vim.deep_equal(blink.sources.default, { 'lsp', 'path', 'snippets' }))
local latex = require 'custom.latex.completion'
assert(vim.deep_equal(blink.sources.per_filetype, latex.blink_sources.per_filetype))
assert(vim.deep_equal(blink.sources.providers, latex.blink_sources.providers))
assert(blink.snippets.preset == 'luasnip' and blink.fuzzy.implementation == 'prefer_rust' and blink.signature.enabled)
print 'Completion tests passed: startup order, plugin declarations, snippet/LaTeX bridge sequencing, preserved Blink options'
