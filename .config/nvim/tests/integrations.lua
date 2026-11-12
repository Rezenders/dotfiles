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
package.loaded.image = { setup = function(config) options.image = config end }
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
assert(not options.image and docks == 1, 'Scrollback must skip image setup, not docks')
vim.env.KITTY_SCROLLBACK_NVIM = nil
kitty.setup()
assert(options.image.backend == 'kitty' and options.image.processor == 'magick_cli')
assert(not options.image.integrations.markdown.download_remote_images)
assert(options.image.max_width == 100 and options.image.max_height == 30 and options.image.max_height_window_percentage == 50)
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
