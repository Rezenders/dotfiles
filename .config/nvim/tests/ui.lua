-- Run from the config directory: nvim --clean -l tests/ui.lua
-- Exercise UI/editing/Git modules with installed plugins and deterministic appearance.
if not arg[1] then
  for _, host in ipairs { 'beast', 'work-test' } do
    for _, appearance in ipairs { 'dark', 'light' } do
      local result = vim.system({ vim.v.progpath, '--clean', '-l', 'tests/ui.lua', host, appearance }, { text = true, timeout = 30000 }):wait()
      assert(result.code == 0, (result.stdout or '') .. (result.stderr or ''))
    end
  end
  print 'UI/editing/Git tests passed: all host/appearance combinations, highlights, module boundaries, editing options, Git mappings and diff wrapping'
  return
end

vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:prepend(vim.fn.stdpath 'data' .. '/site') -- --clean omits user packages.
assert(loadfile 'init.lua')
vim.g.mapleader = ' '
vim.g.have_nerd_font = true
local host, dark = arg[1], arg[2] == 'dark'
---@diagnostic disable-next-line: duplicate-set-field
vim.uv.os_gethostname = function() return host end
package.loaded['custom.runtime'] = { system_is_dark = function() return dark end }
-- Fail instead of installing anything if a required UI plugin is missing.
local add = vim.pack.add
---@diagnostic disable-next-line: duplicate-set-field
vim.pack.add = function(plugins)
  for _, spec in ipairs(plugins) do
    local src = type(spec) == 'table' and spec.src or spec
    local name = src:match('([^/]+)$')
    assert(vim.fn.isdirectory(vim.fn.stdpath 'data' .. '/site/pack/core/opt/' .. name) == 1, 'Missing UI plugin: ' .. name)
  end
  add(plugins, { load = true }) -- -l runs before vim_did_init; load plugins explicitly.
end

local source = table.concat(vim.fn.readfile 'init.lua', '\n')
local section = assert(source:match("(require%('custom%.plugins%.ui'%).setup%(%)\nrequire%('custom%.plugins%.editing'%).setup%(%)\nrequire%('custom%.plugins%.git'%).setup%(%))"))
-- Check the boundary before executing the actual startup sequence.
require('custom.plugins.ui').setup()
assert(not package.loaded.gitsigns and not package.loaded['diffview'] and not package.loaded.gitlinker)
assert(not package.loaded['mini.ai'] and not package.loaded['mini.surround'])
local scope = require('ibl.config').config.scope
assert(scope.enabled and scope.show_start and scope.show_end, 'Indent-guide defaults must remain unchanged')
assert(package.loaded.smartcolumn, 'Line-length guide belongs to UI')
assert(loadstring(section:sub(#"require('custom.plugins.ui').setup()" + 2)))()
assert(MiniAi.config.n_lines == 500)
assert(MiniAi.config.mappings.around_next == 'aa' and MiniAi.config.mappings.inside_next == 'ii')
assert(MiniAi.config.custom_textobjects.d, 'Custom do-block textobject missing')
assert(MiniSurround.config and vim.fn.maparg('sa', 'n') ~= '', 'Surround mappings missing')
assert(package.loaded['guess-indent'] and package.loaded['todo-comments'])
local autopairs = require('nvim-autopairs').config
assert(autopairs.map_cr and not autopairs.check_ts, 'Autopairs defaults must remain unchanged')
assert(not vim.list_contains(autopairs.disable_filetype, 'tex'), 'LaTeX autopairs must not be disabled')
assert(not package.loaded.dap and not package.loaded.dapui and not package.loaded['dap-go'], 'Debugger must not load')
for _, mapping in ipairs(vim.api.nvim_get_keymap('n')) do
  assert(not (mapping.desc or ''):match('^Debug:'), 'Debugger mapping must not remain')
end
local theme = host == 'beast' and (dark and 'kanagawa-dragon' or 'kanagawa-lotus') or 'gruvbox'
assert(vim.g.colors_name == (host == 'beast' and 'kanagawa' or 'gruvbox'), 'Unexpected theme: ' .. tostring(vim.g.colors_name))
if host == 'beast' then assert(require('kanagawa')._CURRENT_THEME == (dark and 'dragon' or 'lotus')) end
assert(vim.o.background == (dark and 'dark' or 'light'))
local palette = { Error = 'GruvboxRed', Warn = 'GruvboxYellow', Info = 'GruvboxBlue', Hint = 'GruvboxAqua' }
local function check_highlights()
  for severity, group in pairs(palette) do
    local underline = vim.api.nvim_get_hl(0, { name = 'DiagnosticUnderline' .. severity, link = false })
    local source = host == 'beast' and ('Diagnostic' .. severity) or group
    assert(underline.undercurl == true, 'Missing diagnostic undercurl')
    assert(underline.sp == vim.api.nvim_get_hl(0, { name = source, link = false }).fg, 'Wrong diagnostic underline color')
  end
end
check_highlights()
vim.cmd.colorscheme(theme)
check_highlights() -- The ColorScheme callback survives initial setup.
assert(vim.fn.maparg(' gd', 'n'):lower() == '<cmd>diffviewopen<cr>')
assert(vim.fn.maparg(' gq', 'n'):lower() == '<cmd>diffviewclose<cr>')
for _, key in ipairs { ' gl', ' gL', ' gb', ' gB' } do
  assert(type(vim.fn.maparg(key, 'n', false, true).callback) == 'function', 'Missing Git link mapping')
end
require('gitsigns.config').config.on_attach(vim.api.nvim_get_current_buf())
assert(vim.fn.maparg(' hs', 'n') ~= '' and vim.fn.maparg(']c', 'n') ~= '', 'Git hunk mappings missing')
vim.wo.wrap, vim.wo.linebreak = false, false
vim.wo.diff = true
vim.api.nvim_exec_autocmds('OptionSet', { pattern = 'diff', group = 'native-diff-wrap' })
assert(vim.wo.wrap and vim.wo.linebreak, 'Native diff wrapping missing')
vim.wo.wrap, vim.wo.linebreak = false, false
require('diffview.config').get_config().hooks.diff_buf_win_enter()
assert(vim.wo.wrap and vim.wo.linebreak, 'Diffview wrapping missing')
assert(require('mini.statusline').section_location() == '%2l:%-2v')
local buf = vim.api.nvim_get_current_buf()
vim.bo[buf].modified = true
assert(MiniTabline.config.format(buf, 'test'):match(' ●$'), 'Modified tab marker missing')
assert(#vim.api.nvim_get_runtime_file('lua/nvim-web-devicons.lua', false) > 0, 'Devicons must be available before later navigation plugins')
