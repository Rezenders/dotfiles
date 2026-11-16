-- Run from the config directory: nvim --clean -l tests/integrations.lua
-- Verify integration guards and bindings without processes, panes, or AI sessions.
---@diagnostic disable: duplicate-set-field
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.g.mapleader = ' '
local added, options, jobs, docks = {}, {}, {}, 0
vim.pack.add = function(plugins)
  for _, spec in ipairs(plugins) do
    local src = type(spec) == 'table' and spec.src or spec
    added[src:match('([^/]+)$')] = true
  end
end
package.loaded['kitty-scrollback'] = { setup = function(config) options.scrollback = config end }
package.loaded.snacks = { setup = function(config) options.snacks = config end }
local discovered = { { type = 'math' }, { type = 'image', src = 'figure.png' }, { type = 'chart' } }
local find_calls, find_buf, find_opts, pending = 0
package.loaded['snacks.image.doc'] = {
  find = function(buf, cb, opts)
    find_calls, find_buf, find_opts = find_calls + 1, buf, opts
    pending = function() cb(discovered) end
  end,
}
local hovered, previews = 0, 0
_G.Snacks = { image = { hover = function() hovered = hovered + 1 end } }
vim.api.nvim_create_user_command('VimtexPreviewToggle', function() previews = previews + 1 end, {})
local splits = { setup = function(config) options.splits = config end }
for _, name in ipairs {
  'move_cursor_left', 'move_cursor_down', 'move_cursor_up', 'move_cursor_right',
  'resize_left', 'resize_down', 'resize_up', 'resize_right',
} do splits[name] = function() end end
package.loaded['smart-splits'] = splits
package.loaded['custom.kitty_docks'] = { setup = function() docks = docks + 1 end }
vim.fn.jobstart = function(command) jobs[#jobs + 1] = command end
local function invoke(lhs, mode)
  local mapping = vim.fn.maparg(lhs, mode or 'n', false, true)
  assert(type(mapping.callback) == 'function', 'Missing callback for ' .. lhs)
  mapping.callback()
end
local kitty = require 'custom.integrations.kitty'
assert(next(added) == nil, 'Require must not initialize integrations')
vim.env.KITTY_SCROLLBACK_NVIM = 'true'
kitty.setup()
assert(not options.snacks.image.enabled and docks == 1, 'Scrollback must disable images, not docks')
vim.env.KITTY_SCROLLBACK_NVIM = nil
kitty.setup()
assert(options.snacks.image.enabled and options.snacks.image.math.enabled)
assert(options.snacks.image.doc.max_width == 80 and options.snacks.image.doc.max_height == 40)
assert(options.snacks.image.doc.enabled and options.snacks.image.doc.inline, 'Keep inline document previews enabled')
local doc = require 'snacks.image.doc'
local tex_buf = vim.api.nvim_create_buf(false, true)
vim.bo[tex_buf].filetype = 'tex'
local range, matches = { from = 1, to = 10 }
doc.find(tex_buf, function(result) matches = result end, range)
assert(find_calls == 1 and find_buf == tex_buf and find_opts == range, 'Forward discovery arguments unchanged')
-- Discovery is asynchronous; use the target buffer, not the current buffer.
vim.bo.filetype = 'markdown'
pending()
assert(#matches == 2 and matches[1] == discovered[2] and matches[2] == discovered[3], 'Only TeX math must be filtered')
assert(#discovered == 3, 'Do not mutate original discovery results')
doc.find(vim.api.nvim_get_current_buf(), function(result) matches = result end)
pending()
assert(matches == discovered, 'Markdown equations and images must pass through unchanged')
doc.find(tex_buf, function(result) matches = result end)
vim.api.nvim_buf_delete(tex_buf, { force = true })
pending()
assert(#matches == 0, 'Ignore results for deleted buffers')
vim.bo.filetype = 'tex'
invoke(' ip')
assert(hovered == 1 and previews == 0, 'LaTeX image hover must use Snacks, not toggle VimTeX')
vim.bo.filetype = 'markdown'
invoke(' ip')
assert(hovered == 2 and previews == 0, 'Markdown must retain Snacks previews')
vim.bo.filetype = ''
local dashboard = options.snacks.dashboard
assert(dashboard.enabled and dashboard.width == 60)
assert(dashboard.preset.header == nil, 'Keep the default Snacks header')
assert(#dashboard.sections == 4 and dashboard.sections[1].section == 'header')
assert(dashboard.sections[2].section == 'keys' and dashboard.sections[2].gap == 1)
assert(dashboard.sections[3].section == 'recent_files' and dashboard.sections[3].limit == 5)
assert(dashboard.sections[4].section == 'projects' and dashboard.sections[4].limit == 4)
assert(dashboard.sections[4].session == false, 'Projects must not attempt session restoration')
local picked, pick_options
package.loaded['fzf-lua'] = {}
for _, name in ipairs { 'files', 'live_grep', 'oldfiles' } do
  package.loaded['fzf-lua'][name] = function(opts) picked, pick_options = name, opts end
end
local keys = {}
for _, item in ipairs(dashboard.preset.keys) do keys[item.key] = item end
for key, picker in pairs { f = 'files', g = 'live_grep', r = 'oldfiles', c = 'files' } do
  keys[key].action()
  assert(picked == picker)
  if key == 'c' then assert(pick_options.cwd == vim.fn.stdpath 'config') end
end
assert(keys.n.action == ':ene | startinsert' and keys.q.action == ':qa')
assert(options.splits.mux.backend == 'smart-splits-backend-kitty' and options.splits.move.at_edge == 'stop' and options.splits.resize.amount == 3)
assert(vim.fn.maparg('<C-h>', 'n', false, true).callback == splits.move_cursor_left)
assert(vim.fn.maparg('<A-l>', 'n', false, true).callback == splits.resize_right)
invoke(' tv')
invoke(' th')
for i, direction in ipairs { 'vsplit', 'hsplit' } do
  assert(vim.deep_equal(jobs[i], { 'kitten', '@', 'launch', '--type=window', '--location=' .. direction, '--cwd=' .. vim.fn.getcwd() }))
end

package.loaded['custom.runtime'] = { setup_pi = function() return nil end }
local pi = require 'custom.integrations.pi'
pi.setup()
assert(vim.fn.maparg(' ps', 'x') == '' and vim.fn.maparg(' pi', 'n') == '', 'Unavailable Pi must not create mappings')
local actions, last = {}, nil
for _, name in ipairs { 'append_selection', 'append_selection_prompt', 'append_file', 'append_buffer' } do
  actions[name] = function() last = name end
end
package.loaded['custom.runtime'].setup_pi = function() return actions end
pi.setup()
invoke(' ps', 'x')
assert(last == 'append_selection')
invoke(' pa', 'x')
assert(last == 'append_selection_prompt')
invoke(' pf')
assert(last == 'append_file')
invoke(' pb')
assert(last == 'append_buffer')
assert(vim.fn.maparg(' pi', 'n'):lower() == '<cmd>piping<cr>')
assert(vim.fn.maparg(' pp', 'n') == ':PiSend<CR>')
assert(vim.fn.maparg(' pF', 'n') == ':PiSendFile<CR>')
assert(vim.fn.maparg(' pS', 'x') == ':PiSendSelection<CR>')
assert(vim.fn.maparg(' pB', 'n') == ':PiSendBuffer<CR>')
package.loaded.claudecode = { setup = function(config) options.claude = config end }
require('custom.integrations.claude').setup()
assert(vim.deep_equal(options.claude.terminal, { provider = 'none', split_side = 'right', split_width_percentage = 0.35 }))
assert(added['claudecode.nvim'])
assert(vim.fn.maparg(' ab', 'n'):lower() == '<cmd>claudecodeadd %<cr>')
assert(vim.fn.maparg(' as', 'x'):lower() == '<cmd>claudecodesend<cr>')
assert(vim.fn.maparg(' aa', 'n'):lower() == '<cmd>claudecodediffaccept<cr>')
assert(vim.fn.maparg(' ad', 'n'):lower() == '<cmd>claudecodediffdeny<cr>')
print 'Integration tests passed: image scrollback guard, smart-splits, launch arguments, optional Pi, Claude external terminal and mappings'
