do
  vim.loader.enable()

  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '
  vim.g.have_nerd_font = true

  vim.o.number = true
  vim.o.relativenumber = false

  -- Enable mouse mode, can be useful for resizing splits for example!
  vim.o.mouse = 'a'

  -- Don't show the mode, since it's already in the status line
  vim.o.showmode = false
  vim.o.laststatus = 3
  vim.o.cmdheight = 0
  -- Experimental message/cmdline UI: avoids "Press ENTER" prompts with cmdheight=0.
  require('vim._core.ui2').enable {}

  -- Unified floating-window style
  vim.o.winborder = 'rounded'
  vim.o.pumborder = 'rounded'

  -- Sync clipboard between OS and Neovim.
  --  Schedule the setting after `UiEnter` because it can increase startup-time.
  --  Remove this option if you want your OS clipboard to remain independent.
  --  See `:help 'clipboard'`
  vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

  vim.o.linebreak = true
  vim.o.breakindent = true

  -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
  vim.o.ignorecase = true
  vim.o.smartcase = true
  -- Keep signcolumn on by default
  vim.o.signcolumn = 'yes'

  -- Decrease update time
  vim.o.updatetime = 250

  -- Decrease mapped sequence wait time
  vim.o.timeoutlen = 300

  -- Configure how new splits should be opened
  vim.o.splitright = true
  vim.o.splitbelow = true

  -- Sets how neovim will display certain whitespace characters in the editor.
  --  See `:help 'list'`
  --  and `:help 'listchars'`
  --
  --  Notice listchars is set using `vim.opt` instead of `vim.o`.
  --  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
  --   See `:help lua-options`
  --   and `:help lua-guide-options`
  vim.o.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
  -- Preview substitutions live, as you type!
  vim.o.inccommand = 'split'

  -- Show which line your cursor is on
  vim.o.cursorline = true

  -- Minimal number of screen lines to keep above and below the cursor.
  vim.o.scrolloff = 12

  -- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
  -- instead raise a dialog asking if you wish to save the current file(s)
  -- See `:help 'confirm'`
  vim.o.confirm = true

  vim.o.exrc = true

  -- START Optimizations for light mode

  -- Uses 24-bit hex definitions colors
  vim.opt.termguicolors = true
  -- END

  -- vim.o.pumblend = 10 -- transparency for popup menu / completions (0-100)
  -- vim.o.winblend = 10  -- keep at 0 if you prefer crisp contrast, or 5-10 for subtle float glass effect

  -- Native Neovim undo tree
  vim.cmd.packadd('nvim.undotree')

  -- Persist undo history across Neovim sessions
  vim.o.undofile = true

  -- Maximum number of undo changes
  vim.o.undolevels = 10000

  -- Toggle undo tree
  vim.keymap.set('n', '<leader>u', '<cmd>Undotree<CR>', {
    desc = 'Toggle undo tree',
  })
end

-- ============================================================
-- SECTION 2: KEYMAPS & AUTOCMDS
-- basic keymaps, basic autocmds
-- ============================================================
do
  -- [[ Basic Keymaps ]]
  --  See `:help vim.keymap.set()`

  -- Clear highlights on search when pressing <Esc> in normal mode
  --  See `:help hlsearch`
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Diagnostic Config & Keymaps
  --  See `:help vim.diagnostic.Opts`
  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    -- Mark problems by underlining the flagged range (every severity); the wavy style
    -- and colours come from the DiagnosticUnderline* groups in polish_ui().
    underline = true,

    -- No inline messages: read them with [d / ]d (float below) or <C-w>d on the word.
    virtual_text = false,
    virtual_lines = false,

    -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }
      end,
    },
    signs = {
      text = {
         [vim.diagnostic.severity.ERROR] = '󰅚 ',
         [vim.diagnostic.severity.WARN]  = '󰀪 ',
         [vim.diagnostic.severity.INFO]  = '󰋽 ',
         [vim.diagnostic.severity.HINT]  = '󰌶 ',
      },
    },
  }

  vim.keymap.set('n', '<leader>q', function()
    vim.diagnostic.setloclist {
      format = function(diagnostic)
        -- Filter both push and pull LTeX+ namespaces, not in-buffer diagnostics.
        local namespace = vim.diagnostic.get_namespace(diagnostic.namespace)
        if namespace.name:match '^nvim%.lsp%.ltex_plus%.' then return nil end
        return diagnostic.message
      end,
    }
  end, { desc = 'Open diagnostic location list (excluding LTeX+)' })

  -- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
  -- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
  -- is not what someone will guess without a bit more experience.
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- TIP: Disable arrow keys in normal mode
  -- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
  -- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
  -- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
  -- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

  -- Keybinds to make split navigation easier.
  --  Use CTRL+<hjkl> to switch between windows
  --
  --  See `:help wincmd` for a list of all window commands
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`

  require('custom.file_autocmds').setup()

  -- Highlight when yanking (copying) text
  --  Try it with `yap` in normal mode
  --  See `:help vim.hl.on_yank()`
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.hl_op() end,
  })

  -- Toggle comments with Ctrl + /
  vim.keymap.set('n', '<C-/>', 'gcc', { remap = true, desc = 'Toggle comment' })
  vim.keymap.set('x', '<C-/>', 'gc', { remap = true, desc = 'Toggle comment' })

  local excluded_filetypes = {
    markdown = true,
    rmd = true,
    quarto = true,
    diff = true,
    gitcommit = true,
  }

  local function trim_trailing_whitespace()
    local view = vim.fn.winsaveview()

    vim.cmd([[silent! keeppatterns keepjumps %s/\s\+$//e]])

    vim.fn.winrestview(view)
  end

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup(
      "trim-trailing-whitespace",
      { clear = true }
    ),

    pattern = "*",

    callback = function(args)
      local buf = args.buf

      -- Ignore special and binary buffers
      if vim.bo[buf].buftype ~= "" or vim.bo[buf].binary then
        return
      end

      -- Ignore filetypes where whitespace may be significant
      if excluded_filetypes[vim.bo[buf].filetype] then
        return
      end

      trim_trailing_whitespace()
    end,
  })
  vim.keymap.set("n", "<leader>x", "<cmd>bd<CR>", {
    desc = "Close current buffer",
  })
end

-- ============================================================
-- SECTION 3: PLUGIN MANAGER INTRO
-- vim.pack intro, build hooks
-- ============================================================
do
-- [[ Intro to `vim.pack` ]]
-- `vim.pack` is a new plugin manager built into Neovim,
--  which provides a Lua interface for installing and managing plugins.
--
--  See `:help vim.pack`, `:help vim.pack-examples` or the
--  excellent blog post from the creator of vim.pack and mini.nvim:
--  https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack
--
--  To inspect plugin state and pending updates, run
--    :lua vim.pack.update(nil, { offline = true })
--
--  To update plugins, run
--    :lua vim.pack.update()

  local function run_build(name, cmd, cwd)
    local result = vim.system(cmd, { cwd = cwd }):wait()
    if result.code ~= 0 then
      local stderr = result.stderr or ''
      local stdout = result.stdout or ''
      local output = stderr ~= '' and stderr or stdout
      if output == '' then output = 'No output from build command.' end
      vim.notify(('Build failed for %s:\n%s'):format(name, output), vim.log.levels.ERROR)
    end
  end

  -- This autocommand runs after a plugin is installed or updated and
  --  runs the appropriate build command for that plugin if necessary.
  --
  -- See `:help vim.pack-events`
  vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
      local name = ev.data.spec.name
      local kind = ev.data.kind
      if kind ~= 'install' and kind ~= 'update' then return end

      if name == 'LuaSnip' then
        if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then run_build(name, { 'make', 'install_jsregexp' }, ev.data.path) end
        return
      end

      if name == 'nvim-treesitter' then
        if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
        vim.cmd 'TSUpdate'
        return
      end
    end,
  })
end

--- Because most plugins are hosted on GitHub, you can use the helper
--- function to have less repetition in the following sections.
---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- SECTION 4: UI / CORE UX PLUGINS
-- guess-indent, gitsigns, which-key, colorscheme, todo-comments, mini modules
-- ============================================================
do
  vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
  require('guess-indent').setup {
    filetype_exclude = {
        'netrw',
        'tutor',
        'tex',
        'plaintex',
    },
  }

  -- Here is a more advanced configuration example that passes options to `gitsigns.nvim`
  --
  -- See `:help gitsigns` to understand what each configuration key does.
  -- Adds git related signs to the gutter, as well as utilities for managing changes
  vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
  local gitsigns = require 'gitsigns'
  gitsigns.setup {
    signs = {
      -- Thin bars for added/changed lines; a Nerd Font caret (U+F0DA) marks where lines were removed.
      add = { text = '▎' }, ---@diagnostic disable-line: missing-fields
      change = { text = '▎' }, ---@diagnostic disable-line: missing-fields
      delete = { text = '\u{f0da}' }, ---@diagnostic disable-line: missing-fields
      topdelete = { text = '\u{f0da}' }, ---@diagnostic disable-line: missing-fields
      changedelete = { text = '▎' }, ---@diagnostic disable-line: missing-fields
    },
    -- gitsigns.nvim's recommended keymaps:
    on_attach = function(bufnr)
      -- Navigation
      vim.keymap.set('n', ']c', function()
        if vim.wo.diff then
          vim.cmd.normal { ']c', bang = true }
        else
          gitsigns.nav_hunk 'next'
        end
      end, { desc = 'Jump to next git [c]hange', buf = bufnr })

      vim.keymap.set('n', '[c', function()
        if vim.wo.diff then
          vim.cmd.normal { '[c', bang = true }
        else
          gitsigns.nav_hunk 'prev'
        end
      end, { desc = 'Jump to previous git [c]hange', buf = bufnr })

      -- Visual mode actions
      vim.keymap.set('v', '<leader>hs', function() gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [s]tage hunk', buf = bufnr })
      vim.keymap.set('v', '<leader>hr', function() gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [r]eset hunk', buf = bufnr })
      -- Normal mode actions
      vim.keymap.set('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk', buf = bufnr })
      vim.keymap.set('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk', buf = bufnr })
      vim.keymap.set('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer', buf = bufnr })
      vim.keymap.set('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer', buf = bufnr })
      vim.keymap.set('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk', buf = bufnr })
      vim.keymap.set('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = 'git preview hunk [i]nline', buf = bufnr })
      vim.keymap.set('n', '<leader>hb', function() gitsigns.blame_line { full = true } end, { desc = 'git [b]lame line', buf = bufnr })
      vim.keymap.set('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index', buf = bufnr })
      vim.keymap.set('n', '<leader>hD', function() gitsigns.diffthis '~' end, { desc = 'git [D]iff against last commit', buf = bufnr })
      vim.keymap.set('n', '<leader>hQ', function() gitsigns.setqflist 'all' end, { desc = 'git hunk [Q]uickfix list (all files in repo)', buf = bufnr })
      vim.keymap.set('n', '<leader>hq', gitsigns.setqflist, { desc = 'git hunk [q]uickfix list (all changes in this file)', buf = bufnr })
      -- Toggles
      vim.keymap.set('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line', buf = bufnr })
      vim.keymap.set('n', '<leader>tw', gitsigns.toggle_word_diff, { desc = '[T]oggle git intra-line [w]ord diff', buf = bufnr })
      -- Text object
      vim.keymap.set({ 'o', 'x' }, 'ih', gitsigns.select_hunk, { desc = 'text object [i]nside [h]unk', buf = bufnr })
    end,
  }

  -- Keep long lines readable in native diff windows (including Gitsigns).
  vim.api.nvim_create_autocmd('OptionSet', {
    group = vim.api.nvim_create_augroup('native-diff-wrap', { clear = true }),
    pattern = 'diff',
    callback = function()
      if vim.wo.diff then
        vim.wo.wrap = true
        vim.wo.linebreak = true
      end
    end,
  })

  -- Repository-wide diff review with a changed-files sidebar.
  vim.pack.add {
    gh 'nvim-lua/plenary.nvim',
    gh 'sindrets/diffview.nvim',
  }
  require('diffview').setup {
    hooks = {
      diff_buf_win_enter = function()
        -- Wrap long paragraphs in both sides of the diff (especially LaTeX).
        vim.opt_local.wrap = true
        vim.opt_local.linebreak = true
      end,
    },
  }

  vim.keymap.set('n', '<leader>gd', '<cmd>DiffviewOpen<CR>', { desc = 'Git: review changes' })
  vim.keymap.set('n', '<leader>gq', '<cmd>DiffviewClose<CR>', { desc = 'Git: close diff review' })
  vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory %<CR>', { desc = 'Git: current file history' })

  -- Generate and copy/open Git permalinks and blame links.
  vim.pack.add { gh 'linrongbin16/gitlinker.nvim' }
  require('gitlinker').setup()
  do
    local gitlinker = require 'gitlinker'
    local actions = require 'gitlinker.actions'

    local function keymap(lhs, opts, desc)
      vim.keymap.set({ 'n', 'v' }, lhs, function() gitlinker.link(opts) end, { silent = true, desc = desc })
    end

    -- browse
    keymap('<leader>gl', {}, 'Copy git permalink')
    keymap('<leader>gL', { action = actions.open }, 'Open git permalink')

    -- blame
    keymap('<leader>gb', { router_type = 'blame' }, 'Copy git blame link')
    keymap('<leader>gB', { router_type = 'blame', action = actions.open }, 'Open git blame link')
  end

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
      { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } }, -- Enable gitsigns recommended keymaps first
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


  -- Highlight todo, notes, etc in comments
  vim.pack.add { gh 'folke/todo-comments.nvim' }
  require('todo-comments').setup { signs = false }

  -- [[ mini.nvim ]]
  --  A collection of various small independent plugins/modules
  vim.pack.add { gh 'nvim-mini/mini.nvim' }

  -- Use the real devicons provider before fzf-lua/statusline/Neo-tree load.
  vim.pack.add { gh 'nvim-tree/nvim-web-devicons' }

  -- Better Around/Inside textobjects
  --
  -- Examples:
  --  - va)  - [V]isually select [A]round [)]paren
  --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
  --  - ci'  - [C]hange [I]nside [']quote
  local ai = require 'mini.ai'

  ai.setup {
    -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
    mappings = {
      around_next = 'aa',
      inside_next = 'ii',
    },
    n_lines = 500,
    custom_textobjects = {
      d = ai.gen_spec.treesitter {
        a = '@do.outer',
        i = '@do.inner',
      },
    },
  }

  -- Add/delete/replace surroundings (brackets, quotes, etc.)
  --
  -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
  -- - sd'   - [S]urround [D]elete [']quotes
  -- - sr)'  - [S]urround [R]eplace [)] [']
  require('mini.surround').setup()

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

-- ============================================================
-- SECTION 5: SEARCH & NAVIGATION
-- fzf-lua setup, keymaps, LSP picker mappings
-- ============================================================
do
  -- fzf-lua uses the external fzf binary. Press <F1> in a picker for help.
  vim.pack.add { gh 'ibhagwan/fzf-lua' }
  local fzf = require 'fzf-lua'
  fzf.setup {
    -- Derive fzf's own colors from the active colorscheme's highlight groups.
    fzf_colors = true,
    -- fzf's list scrollbar leaves stray '│' marks in the float as results stream in.
    fzf_opts = { ['--no-scrollbar'] = true },
    keymap = {
      builtin = {
        ["<C-d>"] = "preview-page-down",
        ["<C-u>"] = "preview-page-up",
      },
    },
    winopts = {
      border = 'rounded',
      width = 0.9,
      height = 0.9,
      cursorline = true,
      -- path_shorten = 2,
      title_pos = 'left',
      preview = {
        layout = 'flex',
        flip_columns = 135, -- anything under 135 cols switches to vertical split
        horizontal = 'right:45%', -- preview on right only in genuinely wide panes
        vertical = 'down:40%', -- preview on bottom in medium/narrow panes

        title_pos = 'left',
        scrollbar = 'float',
      },
    },
    files = {
      formatter = 'path.dirname_first',
    },
  }
  fzf.register_ui_select()

  vim.keymap.set('n', '<leader>sh', fzf.helptags, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sk', fzf.keymaps, { desc = '[S]earch [K]eymaps' })
  vim.keymap.set('n', '<leader>sf', fzf.files, { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>ss', fzf.builtin, { desc = '[S]earch [S]elect picker' })
  vim.keymap.set('n', '<leader>sw', fzf.grep_cword, { desc = '[S]earch current [W]ord' })
  vim.keymap.set('x', '<leader>sw', fzf.grep_visual, { desc = '[S]earch selected [W]ords' })
  vim.keymap.set('n', '<leader>sg', fzf.live_grep, { desc = '[S]earch by [G]rep' })
  vim.keymap.set('n', '<leader>sd', fzf.diagnostics_workspace, { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sr', fzf.resume, { desc = '[S]earch [R]esume' })
  vim.keymap.set('n', '<leader>s.', fzf.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
  vim.keymap.set('n', '<leader>sc', fzf.commands, { desc = '[S]earch [C]ommands' })

  -- buffer navigation
  vim.keymap.set('n', '<leader><leader>', fzf.buffers, { desc = '[ ] Find existing buffers' })
  vim.keymap.set('n', '<leader>bb', '<C-^>', {
    desc = 'Switch to last buffer visited'
  })
  vim.keymap.set('n', '<S-l>', '<cmd>bnext<CR>', {
    desc = 'Next buffer',
  })
  vim.keymap.set('n', '<S-h>', '<cmd>bprevious<CR>', {
    desc = 'Previous buffer',
  })

  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('fzf-lua-lsp-attach', { clear = true }),
    callback = function(event)
      local buf = event.buf
      vim.keymap.set('n', 'grr', fzf.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
      vim.keymap.set('n', 'gri', fzf.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })
      vim.keymap.set('n', 'grd', fzf.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })
      vim.keymap.set('n', 'gO', fzf.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })
      vim.keymap.set('n', 'gW', fzf.lsp_live_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })
      vim.keymap.set('n', 'grt', fzf.lsp_typedefs, { buffer = buf, desc = '[G]oto [T]ype Definition' })
    end,
  })

  vim.keymap.set('n', '<leader>/', function()
    fzf.blines { previewer = false }
  end, { desc = '[/] Fuzzily search in current buffer' })

  vim.keymap.set('n', '<leader>s/', function()
    -- Search the on-disk contents of listed file buffers, not the whole project.
    local paths = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' then
        local name = vim.api.nvim_buf_get_name(buf)
        if name ~= '' and vim.fn.filereadable(name) == 1 then
          paths[#paths + 1] = name
        end
      end
    end
    -- Avoid opening an empty picker when no listed file buffers are searchable.
    if #paths == 0 then
      vim.notify('No open files to search', vim.log.levels.INFO)
      return
    end
    fzf.live_grep { search_paths = paths, prompt = 'Grep Open Files> ' }
  end, { desc = '[S]earch [/] in Open Files' })

  vim.keymap.set('n', '<leader>sn', function()
    fzf.files { cwd = vim.fn.stdpath 'config', cmd = 'rg --files --follow --glob !.git' }
  end, { desc = '[S]earch [N]eovim files' })
end

-- ============================================================
-- SECTION 6: LSP
-- LSP keymaps, server configuration, Mason tools installations
-- ============================================================
do
  -- Useful status updates for LSP.
  vim.pack.add { gh 'j-hui/fidget.nvim' }
  require('fidget').setup {
    notification = {
      -- override_vim_notify = true,

      -- window = {
        -- border = 'rounded',
        -- winblend = 0,
        -- normal_hl = 'NormalFloat',
        -- x_padding = 1,
        -- y_padding = 1,
      -- },
    },
  }

  --  This function gets run when an LSP attaches to a particular buffer.
  --    That is to say, every time a new file is opened that is associated with
  --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
  --    function will be executed to configure the current buffer
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
    callback = function(event)
      -- NOTE: Remember that Lua is a real programming language, and as such it is possible
      -- to define small helper and utility functions so you don't have to repeat yourself.
      --
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
  --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
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
    -- rust_analyzer = {},

    stylua = {}, -- Used to format Lua code

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
  -- its completion capabilities. UI/snippet setup stays in section 8 below.
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
    'markdownlint', -- Markdown linting (nvim-lint)
  })

  require('mason-tool-installer').setup { ensure_installed = ensure_installed }

  require('kickstart.health').lsp_servers = vim.tbl_keys(servers)
  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end
end

-- Markdown formatting (manual only).
do
  vim.pack.add { gh 'stevearc/conform.nvim' }

  require('conform').setup {
    formatters_by_ft = {
      -- Respect project Prettier configuration (no personal CLI overrides).
      markdown = { 'prettier' },
    },
  }

  vim.keymap.set('n', '<leader>mf', function()
    require('conform').format { async = true }
  end, { desc = 'Format document' })

  vim.pack.add({
    'https://github.com/OXY2DEV/markview.nvim',
  })

  require('markview').setup({})

  -- Toggle Markdown rendering
  vim.keymap.set('n', '<leader>mp', '<cmd>Markview<cr>',
    { desc = 'Toggle Markdown preview' })

  -- Toggle side-by-side Markdown preview
  vim.keymap.set('n', '<leader>ms', '<cmd>Markview splitToggle<cr>',
    { desc = 'Toggle Markdown split preview' })

end

-- ============================================================
-- SECTION 8: AUTOCOMPLETE & SNIPPETS
-- blink.cmp and luasnip setup
-- ============================================================
do
  -- [[ Snippet Engine ]]
  vim.pack.add { { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' } }
  require('luasnip').setup {
    enable_autosnippets = true,
  }

  -- `friendly-snippets` contains a variety of premade snippets.
  --    See the README about individual language/framework/plugin snippets:
  --    https://github.com/rafamadriz/friendly-snippets
  --
  vim.pack.add { gh 'rafamadriz/friendly-snippets' }
  require('luasnip.loaders.from_vscode').lazy_load()

  -- VimTeX completion source for blink.cmp
  local latex_completion = require 'custom.latex.completion'
  latex_completion.setup()

  -- [[ Autocomplete Engine ]]
  -- Blink was added in section 6 for LSP capabilities; configure it only now,
  -- after LuaSnip and the LaTeX completion source are ready.
  require('blink.cmp').setup {
    keymap = {
      -- 'default' (recommended) for mappings similar to built-in completions
      --   <c-y> to accept ([y]es) the completion.
      --    This will auto-import if your LSP supports it.
      --    This will expand snippets if the LSP sent a snippet.
      -- 'super-tab' for tab to accept
      -- 'enter' for enter to accept
      -- 'none' for no mappings
      --
      -- For an understanding of why the 'default' preset is recommended,
      -- you will need to read `:help ins-completion`
      --
      -- No, but seriously. Please read `:help ins-completion`, it is really good!
      --
      -- All presets have the following mappings:
      -- <tab>/<s-tab>: move to right/left of your snippet expansion
      -- <c-space>: Open menu or open docs if already open
      -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
      -- <c-e>: Hide menu
      -- <c-k>: Toggle signature help
      --
      -- See `:help blink-cmp-config-keymap` for defining your own keymap
      preset = 'default',

      -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
      --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
    },

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = 'mono',
    },

    completion = {
      -- By default, you may press `<c-space>` to show the documentation.
      -- Optionally, set `auto_show = true` to show the documentation after a delay.
      documentation = { auto_show = true, auto_show_delay_ms = 500 },
      -- Colour completion labels from LSP items with treesitter highlighting.
      menu = { draw = { treesitter = { 'lsp' } } },
    },

    -- VimTeX source for LaTeX files comes from custom.latex.completion
    sources = vim.tbl_deep_extend('error', {
      default = { 'lsp', 'path', 'snippets' },
    }, latex_completion.blink_sources),

    snippets = { preset = 'luasnip' },

    -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
    -- which automatically downloads a prebuilt binary when enabled.
    --
    -- By default, we use the Lua implementation instead, but you may enable
    -- the rust implementation via `'prefer_rust_with_warning'`
    --
    -- See `:help blink-cmp-config-fuzzy` for more information
    fuzzy = { implementation = 'prefer_rust' },

    -- Shows a signature help window while you type arguments for a function
    signature = { enabled = true },
  }
end

-- ============================================================
-- SECTION 9: TREESITTER
-- Parser installation, syntax highlighting, folds, indentation
-- ============================================================
do
  vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

  -- Ensure basic parsers are installed
  local parsers = {
      'bash',
      'c',
      'diff',
      'html',
      'lua',
      'luadoc',
      'markdown',
      'markdown_inline',
      'query',
      'vim',
      'vimdoc'
  }
  require('nvim-treesitter').install(parsers)

  vim.o.foldlevel = 99       -- Don't fold everything by default when opening a file
  vim.o.foldlevelstart = 99  -- Start with all folds open

  local attached_languages = {}

  local function buffer_has_language(buf, language)
    return vim.api.nvim_buf_is_loaded(buf)
      and vim.treesitter.language.get_lang(vim.bo[buf].filetype) == language
  end

  local function treesitter_folds(buf)
    local language = attached_languages[buf]
    if not language or not buffer_has_language(buf, language) then return end
    local ts_foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      -- Respect a fold method chosen elsewhere (modeline, ftplugin, :set): only take
      -- over the default 'manual', or re-apply our own treesitter expr.
      local wo = vim.wo[win][0]
      if wo.foldmethod == 'manual' or (wo.foldmethod == 'expr' and wo.foldexpr == ts_foldexpr) then
        -- Set only the window-local value, not the default for future buffers.
        wo.foldexpr = ts_foldexpr
        wo.foldmethod = 'expr'
      end
    end
  end

  vim.api.nvim_create_autocmd('BufWinEnter', {
    callback = function(args) treesitter_folds(args.buf) end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    callback = function(args) attached_languages[args.buf] = nil end,
  })

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    -- Installation may finish after the buffer is unloaded or its filetype changes.
    if not buffer_has_language(buf, language) then return end

    -- Check if a parser exists and load it
    if not vim.treesitter.language.add(language) then return end

    -- Enable syntax highlighting and other treesitter features
    vim.treesitter.start(buf, language)

    -- Folding belongs to each window displaying this buffer, including later ones.
    attached_languages[buf] = language
    treesitter_folds(buf)

    -- Check if treesitter indentation is available for this language, and if so enable it
    -- in case there is no indent query, the indentexpr will fallback to the vim's built in one
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil

    -- Enable treesitter based indentation
    if has_indent_query then vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match

      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end
      -- VimTeX needs its own regex syntax (math detection, conceal, live preview);
      -- starting treesitter on tex buffers turns that syntax off.
      if language == 'latex' then return end

      local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

      if vim.tbl_contains(installed_parsers, language) then
        -- Enable the parser if it is already installed
        treesitter_try_attach(buf, language)
      elseif vim.tbl_contains(available_parsers, language) then
        -- If a parser is available in `nvim-treesitter`, auto-install it and enable it after the installation is done
        require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
      else
        -- Try to enable treesitter features in case the parser exists but is not available from `nvim-treesitter`
        treesitter_try_attach(buf, language)
      end
    end,
  })
  end

-- ============================================================
-- SECTION 10: OPTIONAL EXAMPLES / NEXT STEPS
-- kickstart.plugins.* examples
-- ============================================================
do
  require 'kickstart.plugins.debug'
  require 'kickstart.plugins.indent_line'
  require 'kickstart.plugins.lint'
  require('custom.line_length').setup()
  require 'kickstart.plugins.autopairs'

  vim.pack.add({
    {
      src = 'https://github.com/nvim-neo-tree/neo-tree.nvim',
      version = vim.version.range('3')
    },
    -- dependencies
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/MunifTanjim/nui.nvim",
  })

  vim.keymap.set('n', '\\', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })

  require('neo-tree').setup {
    popup_border_style = 'rounded',
    filesystem = {
      window = {
        mappings = {
          ['\\'] = 'close_window',
          ['Y'] = function(state)
             local node = state.tree:get_node()
             local path = vim.fn.fnamemodify(node:get_id(), ':.')
             vim.fn.setreg('+', path)
             vim.notify('Copied: ' .. path)
          end,
        },
      },
    },
    source_selector = {
      winbar = true,
      statusline = false,
      content_layout = 'center',
      tabs_layout = 'equal',
      show_separator_on_edge = false,

      sources = {
        { source = 'filesystem', display_name = ' 󰉓 Files ' },
        { source = 'buffers',    display_name = ' 󰈚 Buffers ' },
        { source = 'git_status', display_name = ' 󰊢 Git ' },
      },

      separator = {
        left = ' ',
        right = ' ',
      },
    }
  }
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'neo-tree-popup',
    callback = function()
      vim.opt_local.list = false
      vim.opt_local.cursorline = false
    end,
  })
end

-- Section 11: kitty integration
do
  -- [[ Scrollback browsing ]]
  vim.pack.add { gh 'mikesmithgh/kitty-scrollback.nvim' }
  require('kitty-scrollback').setup {}

  -- [[ Image support ]]
  vim.pack.add {
    { src = 'https://github.com/3rd/image.nvim' },
  }

  -- Avoid image rendering conflicts in kitty-scrollback's Neovim instance.
  if vim.env.KITTY_SCROLLBACK_NVIM ~= 'true' then
    require('image').setup {
      backend = 'kitty',
      processor = 'magick_cli',

      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = false,
          only_render_image_at_cursor = false,
          filetypes = { 'markdown' },
        },
      },

      max_width = 100,
      max_height = 30,
      max_width_window_percentage = 100,
      max_height_window_percentage = 50,
    }
  end
  -- [[ Smart Splits ]]
  vim.pack.add {
    { src = 'https://github.com/smart-splits-nvim/smart-splits.nvim' },
    { src = 'https://github.com/smart-splits-nvim/backend-kitty' },
  }

  require('smart-splits').setup {
    mux = {
      backend = 'smart-splits-backend-kitty',
    },
    move = {
      at_edge = 'stop',
    },
    resize = {
      amount = 3,
    },
  }

  local splits = require('smart-splits')

  -- Navigation
  vim.keymap.set('n', '<C-h>', splits.move_cursor_left)
  vim.keymap.set('n', '<C-j>', splits.move_cursor_down)
  vim.keymap.set('n', '<C-k>', splits.move_cursor_up)
  vim.keymap.set('n', '<C-l>', splits.move_cursor_right)

  -- Resizing
  vim.keymap.set('n', '<A-h>', splits.resize_left)
  vim.keymap.set('n', '<A-j>', splits.resize_down)
  vim.keymap.set('n', '<A-k>', splits.resize_up)
  vim.keymap.set('n', '<A-l>', splits.resize_right)

  local function kitty_split(direction)
    vim.fn.jobstart({
      'kitten', '@', 'launch',
      '--type=window',
      '--location=' .. direction,
      '--cwd=' .. vim.fn.getcwd(),
    })
  end
  -- Side by side
  vim.keymap.set('n', '<leader>tv', function()
    kitty_split('vsplit')
  end, { desc = 'Kitty vertical split' })

  -- Top and bottom
  vim.keymap.set('n', '<leader>th', function()
    kitty_split('hsplit')
  end, { desc = 'Kitty horizontal split' })

  -- [[ Kitty docks ]]
  require('custom.kitty_docks').setup()
end

-- Section 12: Latex integration
-- VimTeX + LaTeX snippets. LSP servers and completion are wired in sections 6 and 8;
-- buffer-local options/keymaps are in after/ftplugin/tex.lua. See lua/custom/latex/.
do
  require('custom.latex').setup()
end


-- Pi integration
do
  -- Optional local development fork; reproduction details: INTEGRATIONS.md.
  local pi = require('custom.runtime').setup_pi()
  if pi then
    vim.keymap.set("x", "<leader>ps", pi.append_selection,
      { desc = "Add selection to Pi draft (no submit)" })
    vim.keymap.set("x", "<leader>pa", pi.append_selection_prompt,
      { desc = "Add selection with message to Pi draft (no submit)" })
    vim.keymap.set("n", "<leader>pf", pi.append_file,
      { desc = "Add file reference to Pi draft" })
    vim.keymap.set("n", "<leader>pb", pi.append_buffer,
      { desc = "Add buffer to Pi draft (no submit)" })

    vim.keymap.set("n", "<leader>pi", "<cmd>PiPing<CR>",
      { desc = "Ping Pi session" })

    vim.keymap.set("n", "<leader>pp", ":PiSend<CR>",
     { desc = "Send prompt to Pi & submit" })

    vim.keymap.set("n", "<leader>pF", ":PiSendFile<CR>",
     { desc = "Send file to Pi & submit" })
    vim.keymap.set("v", "<leader>pS", ":PiSendSelection<CR>",
     { desc = "Send selection to Pi & submit" })
    vim.keymap.set("n", "<leader>pB", ":PiSendBuffer<CR>",
     { desc = "Send buffer to Pi & submit" })
  end
end
-- ============================================================
-- Claude Code integration
-- ============================================================
do
  vim.pack.add {
    gh 'coder/claudecode.nvim',
  }

  require('claudecode').setup({
    terminal = {
      provider = 'none',
      split_side = 'right',
      split_width_percentage = 0.35,
    },
  })

  -- Keybindings
  -- Claude runs in a kitty pane (`claude --ide`); provider 'none' cannot
  -- toggle or focus it, so pane switching/zoom is handled by kitty.
  -- Pi runs in a kitty dock pane via make_dock_launcher inheriting Neovim's environment.
  vim.keymap.set('n', '<leader>ab', '<cmd>ClaudeCodeAdd %<CR>',
    { desc = 'Add current buffer to Claude' })

  vim.keymap.set('v', '<leader>as', '<cmd>ClaudeCodeSend<CR>',
    { desc = 'Send selection to Claude' })

  vim.keymap.set('n', '<leader>aa', '<cmd>ClaudeCodeDiffAccept<CR>',
    { desc = 'Accept Claude diff' })

  vim.keymap.set('n', '<leader>ad', '<cmd>ClaudeCodeDiffDeny<CR>',
    { desc = 'Reject Claude diff' })
end

