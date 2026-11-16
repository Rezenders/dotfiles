-- nvim --clean -l tests/appearance.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local appearance = require 'custom.appearance'
local esc = '\027'
for _, case in ipairs {
  { ']11;rgb:0/0/0', 'dark' },
  { ']11;rgb:ff/ff/ff', 'light' },
  { ']11;rgb:ffff/ffff/ffff', 'light' },
  { ']11;rgba:1111/1111/1111/ffff', 'dark' },
  { ']11;rgba:f/f/f/0', 'light' },
  { ']11;rgb:00000/0000/0000' },
  { ']11;rgba:0/0/0/00000' },
  { ']11;rgb:xx/00/00' },
  { ']11;rgb:00/00' },
  { ']10;rgb:ff/ff/ff' },
  { '[?997;1n' }, -- the TUI turns notifications into OSC 11 queries
} do
  assert(appearance.background_from_response(esc .. case[1]) == case[2], case[1])
end

local fallback_calls, themes, queries = 0, {}, {}
package.loaded['custom.runtime'] = {
  system_is_dark = function()
    fallback_calls = fallback_calls + 1
    return false
  end,
}
local has_ui, known_background = false, false
---@diagnostic disable: duplicate-set-field
vim.api.nvim_list_uis = function() return has_ui and { {} } or {} end
vim.api.nvim_get_option_info2 = function() return { was_set = known_background } end
vim.api.nvim_ui_send = function(payload) queries[#queries + 1] = payload end
vim.cmd.colorscheme = function(theme) themes[#themes + 1] = theme end
local function respond(sequence) vim.api.nvim_exec_autocmds('TermResponse', { data = { sequence = esc .. sequence } }) end
appearance.setup(true)
assert(vim.o.background == 'light' and themes[1] == 'kanagawa')
assert(fallback_calls == 1 and #queries == 0, 'Headless setup must not query a terminal')
has_ui = true
vim.api.nvim_exec_autocmds 'UIEnter'
assert(#queries == 1 and queries[1] == esc .. ']11;?\007')
respond ']11;rgb:0000/0000/0000'
assert(vim.o.background == 'dark' and #themes == 2)
respond ']11;rgb:0000/0000/0000'
respond ']10;rgb:ffff/ffff/ffff'
assert(#themes == 2, 'Duplicate/unrelated responses must not reload themes')
respond ']11;rgb:ffff/ffff/ffff'
assert(vim.o.background == 'light' and #themes == 3)
assert(fallback_calls == 1, 'Live changes must never run desktop queries')

-- Native startup detection wins over a contradictory desktop preference.
known_background = true
vim.o.background = 'dark'
appearance.setup(false)
assert(vim.o.background == 'dark' and themes[#themes] == 'gruvbox')
assert(fallback_calls == 1 and #queries == 2)
assert(#vim.api.nvim_get_autocmds { group = 'custom-appearance', event = 'TermResponse' } == 1, 'Repeated setup must replace listeners')
respond ']11;rgb:ffff/ffff/ffff'
assert(vim.o.background == 'light' and themes[#themes] == 'gruvbox')
print 'Appearance tests passed: RGB(A) parsing, headless fallback, late UI attach, native startup preference, live updates and deduplication'
