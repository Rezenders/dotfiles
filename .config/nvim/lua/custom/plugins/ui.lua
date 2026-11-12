-- Interface, themes, highlights, icons, and status displays.
local M = {}

local function gh(repo) return 'https://github.com/' .. repo end

function M.setup()
  -- Useful plugin to show you pending keybinds.
  vim.pack.add { gh 'folke/which-key.nvim' }
  require('which-key').setup {
    preset = 'modern',
    win = {
       border = 'rounded', -- 'single', 'double', 'rounded', 'shadow'
    },
    icons = { mappings = vim.g.have_nerd_font },
    -- Delay between pressing a key and opening which-key (milliseconds)
    delay = 0,
    -- Document existing key chains
    spec = {
      { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>g', group = '[G]it', mode = { 'n', 'v' } },
      { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } }, -- Git hunk mappings are configured in custom.plugins.git
      { 'gr', group = 'LSP Actions', mode = { 'n' } },
    },
  }
  -- Desktop appearance is optional and bounded; light is the fallback.
  local system_is_dark = require('custom.runtime').system_is_dark

  -- [[ Colorscheme ]]
  -- One theme family per machine (personal vs work), then dark/light from the desktop.
  -- If you want to see what colorschemes are already installed, you can use `:FzfLua colorschemes`.

  -- Work machine: gruvbox, solid background.
  vim.pack.add { gh 'morhetz/gruvbox' }
  vim.g.gruvbox_contrast_dark = 'medium'
  vim.g.gruvbox_contrast_light = 'medium'
  vim.g.gruvbox_italic = 0

  -- Personal machine: Kanagawa (dragon = dark, lotus = light), see-through background.
  vim.pack.add { gh 'rebelot/kanagawa.nvim' }
  require('kanagawa').setup {
    transparent = true,
    -- Gutter (signs, line numbers) uses no background so it blends with the transparent editor.
    colors = { theme = { all = { ui = { bg_gutter = 'none' } } } },
    background = { dark = 'dragon', light = 'lotus' },
  }

  local function polish_ui()
    vim.api.nvim_set_hl(0, 'SignColumn', { bg = 'NONE' })

    -- Hand-tuned gruvbox-dark extras (work look, unchanged). Other themes keep their own.
    if vim.g.colors_name == 'gruvbox' and vim.o.background == 'dark' then
      vim.api.nvim_set_hl(0, 'WinSeparator', { fg = '#504945', bg = 'NONE' })
      vim.api.nvim_set_hl(0, 'FoldColumn', { fg = '#7c6f64', bg = 'NONE' })
      vim.api.nvim_set_hl(0, 'WhichKeyNormal', { bg = '#1d2021', fg = '#ebdbb2' })
      vim.api.nvim_set_hl(0, 'WhichKeyBorder', { bg = '#1d2021', fg = '#504945' })
      vim.api.nvim_set_hl(0, 'WhichKeyTitle', { bg = '#1d2021', fg = '#fabd2f', bold = true })
    end

    -- Wavy (undercurl) diagnostic underlines; `sp` colours the line, not the text.
    -- The colour comes from the active theme. morhetz/gruvbox doesn't define the
    -- Diagnostic* groups, so use its own palette groups there instead.
    local gruvbox_source = { Error = 'GruvboxRed', Warn = 'GruvboxYellow', Info = 'GruvboxBlue', Hint = 'GruvboxAqua' }
    for _, severity in ipairs { 'Error', 'Warn', 'Info', 'Hint' } do
      local source = vim.g.colors_name == 'gruvbox' and gruvbox_source[severity] or ('Diagnostic' .. severity)
      local color = vim.api.nvim_get_hl(0, { name = source, link = false }).fg
      vim.api.nvim_set_hl(0, 'DiagnosticUnderline' .. severity, { undercurl = true, sp = color })
    end
  end

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('ui-polish', { clear = true }),
    callback = polish_ui,
  })

  -- `beast` is the personal machine; every other host gets the work theme.
  local personal = vim.uv.os_gethostname() == 'beast'
  local dark = system_is_dark()
  vim.o.background = dark and 'dark' or 'light'
  if personal then
    vim.cmd.colorscheme(dark and 'kanagawa-dragon' or 'kanagawa-lotus')
  else
    vim.cmd.colorscheme 'gruvbox'
  end


  -- Indentation guides use the plugin defaults.
  vim.pack.add { gh 'lukas-reineke/indent-blankline.nvim' }
  require('ibl').setup {}

  vim.pack.add { gh 'm4xshen/smartcolumn.nvim' }
  require('smartcolumn').setup {
    colorcolumn = '80', -- Fallback when EditorConfig does not specify a width.
    custom_colorcolumn = { ruby = '90' }, -- Ruby fallback; EditorConfig still takes precedence.
    disabled_filetypes = { 'help' }, -- Keep the guide available in Markdown and text.
    scope = 'file', -- Show the guide if any line in the file exceeds the limit.
    editorconfig = true, -- Prefer the project's max_line_length when available.
  }

  -- [[ mini.nvim ]]
  --  A collection of various small independent plugins/modules
  vim.pack.add { gh 'nvim-mini/mini.nvim' }

  -- Use the real devicons provider before fzf-lua/statusline/Neo-tree load.
  vim.pack.add { gh 'nvim-tree/nvim-web-devicons' }

  -- Simple and easy statusline.
  local statusline = require 'mini.statusline'
  -- Set `use_icons` to true if you have a Nerd Font
  statusline.setup {
    use_icons = vim.g.have_nerd_font,
  }

  -- You can configure sections in the statusline by overriding their
  -- default behavior. For example, here we set the section for
  -- cursor location to LINE:COLUMN
  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_location = function() return '%2l:%-2v' end

  require('mini.statuscolumn').setup()
  require('mini.tabline').setup({
    format = function(buf_id, label)
      local name = MiniTabline.default_format(buf_id, label)

      if vim.bo[buf_id].modified then
        return name .. ' ●'
      end

      return name
    end,
  })
end

return M
