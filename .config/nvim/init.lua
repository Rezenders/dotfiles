do
	vim.loader.enable()
	-- Set <space> as the leader key
	-- See `:help mapleader`
	--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
	vim.g.mapleader = ' '
	vim.g.maplocalleader = ' '
	vim.g.have_nerd_font = true

	vim.o.number = true
	vim.o.relativenumber = false

	-- Enable mouse mode, can be useful for resizing splits for example!
	vim.o.mouse = 'a'

	-- Don't show the mode, since it's already in the status line
	vim.o.showmode = true

	-- Sync clipboard between OS and Neovim.
	--  Schedule the setting after `UiEnter` because it can increase startup-time.
	--  Remove this option if you want your OS clipboard to remain independent.
	--  See `:help 'clipboard'`
	vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

	vim.o.linebreak = true
	vim.o.breakindent = true

	-- Enable undo/redo changes even after closing and reopening a file
	vim.o.undofile = true

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
	vim.o.scrolloff = 10

	-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
	-- instead raise a dialog asking if you wish to save the current file(s)
	-- See `:help 'confirm'`
	vim.o.confirm = true

  vim.o.exrc = true
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
    underline = { severity = { min = vim.diagnostic.severity.WARN } },

    -- Can switch between these as you prefer
    virtual_text = true, -- Text shows up at the end of the line
    virtual_lines = false, -- Text shows up underneath the line, with virtual lines

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
  }

  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

  -- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
  -- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
  -- is not what someone will guess without a bit more experience.
  --
  -- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
  -- or just use <C-\><C-n> to exit terminal mode
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
  --
  --
  --  Throughout the rest of the config there will be examples
  --  of how to install and configure plugins using `vim.pack`.
  --
  --  In this section we set up some autocommands to run build
  --  steps for certain plugins after they are installed or updated.

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
  -- [[ Installing and Configuring Plugins ]]
  --
  -- To install a plugin simply call `vim.pack.add` with its git url.
  -- This will download the default branch of the plugin, which will usually be `main` or `master`
  -- You can also have more advanced specs, which we will talk about later.
  --
  -- For most plugins its not enough to install them, you also need to call their `.setup()` to start them.
  --
  -- For example, lets say we want to install `guess-indent.nvim` - a plugin for
  -- automatically detecting and setting the indentation.
  --
  -- We first install it from https://github.com/NMAC427/guess-indent.nvim
  -- and then call its `setup()` function to start it with default settings.
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
      add = { text = '+' }, ---@diagnostic disable-line: missing-fields
      change = { text = '~' }, ---@diagnostic disable-line: missing-fields
      delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
      topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
      changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
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

  -- Useful plugin to show you pending keybinds.
  vim.pack.add { gh 'folke/which-key.nvim' }
  require('which-key').setup {
    -- Delay between pressing a key and opening which-key (milliseconds)
    delay = 0,
    icons = { mappings = vim.g.have_nerd_font },
    -- Document existing key chains
    spec = {
      { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>g', group = '[G]it' },
      { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } }, -- Enable gitsigns recommended keymaps first
      { 'gr', group = 'LSP Actions', mode = { 'n' } },
    },
  }
  -- Detect desktop color scheme (GNOME / KDE Plasma).
  local function system_is_dark()
    local result = vim.system({
      'gdbus', 'call', '--session',
      '--dest', 'org.freedesktop.portal.Desktop',
      '--object-path', '/org/freedesktop/portal/desktop',
      '--method', 'org.freedesktop.portal.Settings.Read',
      'org.freedesktop.appearance', 'color-scheme',
    }, { text = true }):wait()

    if result.code ~= 0 then
      return false
    end

    local scheme = tonumber(result.stdout:match('uint32%s+(%d+)'))
    return scheme == 1
  end
  -- [[ Colorscheme ]]
  -- You can easily change to a different colorscheme.
  -- Change the name of the colorscheme plugin below, and then
  -- change the command under that to load whatever the name of that colorscheme is.
  --
  -- If you want to see what colorschemes are already installed, you can use `:FzfLua colorschemes`.
  -- vim.pack.add { gh 'folke/tokyonight.nvim' }
  -- ---@diagnostic disable-next-line: missing-fields
  -- require('tokyonight').setup {
  --   styles = {
  --     comments = { italic = false }, -- Disable italics in comments
  --   },
  -- }
  -- Load the colorscheme here.
  -- Like many other themes, this one has different styles, and you could load
  -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
  -- vim.cmd.colorscheme 'tokyonight-day'
  -- [[ Colorscheme ]]
  -- vim.pack.add { gh 'folke/tokyonight.nvim' }
  --
  -- require('tokyonight').setup {
  --   style = 'moon',
  --   light_style = 'day',
  --   styles = {
  --     comments = { italic = false },
  --   },
  -- }
  --
  -- vim.pack.add { gh 'webhooked/kanso.nvim' }
  --
  -- require('kanso').setup {
  --   background = {
  --     dark = 'ink',
  --     light = 'pearl',
  --   },
  --   transparent = false,
  --   foreground = 'default',
  --   commentStyle = { italic = false },
  -- }
  -- [[ Colorscheme ]]
  vim.pack.add { gh 'morhetz/gruvbox' }

  -- Gruvbox configuration
  vim.g.gruvbox_contrast_dark = 'medium'
  vim.g.gruvbox_contrast_light = 'medium'
  vim.g.gruvbox_italic = 0

  vim.pack.add { gh 'ClearAspect/onehalf' }
  require('onehalf').setup {
    transparency = false,
  }
  -- vim.o.background = system_is_dark() and 'dark' or 'light'
  -- vim.cmd.colorscheme 'tokyonight'
  -- vim.cmd.colorscheme 'kanso'
  -- vim.cmd.colorscheme 'gruvbox'
  -- Apply colorscheme based on desktop appearance.
  if system_is_dark() then
    vim.o.background = 'dark'
    vim.cmd.colorscheme 'gruvbox'
  else
    vim.o.background = 'light'
    vim.cmd.colorscheme 'onehalflight'
  end


  -- One Half clears Diffview's diff groups; restore their standard links.
  local function restore_diffview_highlights()
    for group, target in pairs {
      DiffviewDiffAdd = 'DiffAdd',
      DiffviewDiffDelete = 'DiffDelete',
      DiffviewDiffChange = 'DiffChange',
      DiffviewDiffText = 'DiffText',
      DiffviewDiffAddAsDelete = 'DiffDelete',
      DiffviewDiffDeleteDim = 'Comment',
    } do
      vim.api.nvim_set_hl(0, group, { link = target })
    end
  end
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('diffview-theme-highlights', { clear = true }),
    callback = restore_diffview_highlights,
  })
  restore_diffview_highlights()

  -- Highlight todo, notes, etc in comments
  vim.pack.add { gh 'folke/todo-comments.nvim' }
  require('todo-comments').setup { signs = false }

  -- [[ mini.nvim ]]
  --  A collection of various small independent plugins/modules
  vim.pack.add { gh 'nvim-mini/mini.nvim' }

  -- If a nerd font is available, load the icons module for pretty icons in various plugins.
  if vim.g.have_nerd_font then
    require('mini.icons').setup()
    -- Used for backwards compatibility with plugins that require `nvim-web-devicons` (e.g. neo-tree.nvim)
    MiniIcons.mock_nvim_web_devicons()
  end

  -- Better Around/Inside textobjects
  --
  -- Examples:
  --  - va)  - [V]isually select [A]round [)]paren
  --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
  --  - ci'  - [C]hange [I]nside [']quote
  require('mini.ai').setup {
    -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
    mappings = {
      around_next = 'aa',
      inside_next = 'ii',
    },
    n_lines = 500,
  }

  -- Add/delete/replace surroundings (brackets, quotes, etc.)
  --
  -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
  -- - sd'   - [S]urround [D]elete [']quotes
  -- - sr)'  - [S]urround [R]eplace [)] [']
  require('mini.surround').setup()

  -- Simple and easy statusline.
  --  You could remove this setup call if you don't like it,
  --  and try some other statusline plugin
  local statusline = require 'mini.statusline'
  -- Set `use_icons` to true if you have a Nerd Font
  statusline.setup { use_icons = vim.g.have_nerd_font }

  -- You can configure sections in the statusline by overriding their
  -- default behavior. For example, here we set the section for
  -- cursor location to LINE:COLUMN
  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_location = function() return '%2l:%-2v' end

  -- ... and there is more!
  --  Check out: https://github.com/nvim-mini/mini.nvim
end

-- ============================================================
-- SECTION 5: SEARCH & NAVIGATION
-- fzf-lua setup, keymaps, LSP picker mappings
-- ============================================================
do
  -- fzf-lua uses the external fzf binary. Press <F1> in a picker for help.
  vim.pack.add { gh 'ibhagwan/fzf-lua' }
  local fzf = require 'fzf-lua'
  fzf.setup {}
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
  vim.keymap.set('n', '<leader><leader>', fzf.buffers, { desc = '[ ] Find existing buffers' })

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
  -- [[ LSP Configuration ]]
  -- Brief aside: **What is LSP?**
  --
  -- LSP is an initialism you've probably heard, but might not understand what it is.
  --
  -- LSP stands for Language Server Protocol. It's a protocol that helps editors
  -- and language tooling communicate in a standardized fashion.
  --
  -- In general, you have a "server" which is some tool built to understand a particular
  -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
  -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
  -- processes that communicate with some "client" - in this case, Neovim!
  --
  -- LSP provides Neovim with features like:
  --  - Go to definition
  --  - Find references
  --  - Autocompletion
  --  - Symbol Search
  --  - and more!
  --
  -- Thus, Language Servers are external tools that must be installed separately from
  -- Neovim. This is where `mason` and related plugins come into play.
  --
  -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
  -- and elegantly composed help section, `:help lsp-vs-treesitter`

  -- Useful status updates for LSP.
  vim.pack.add { gh 'j-hui/fidget.nvim' }
  require('fidget').setup {}

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
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.clear_references,
        })

        vim.api.nvim_create_autocmd('LspDetach', {
          group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
          callback = function(event2)
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
          end,
        })
      end

      -- The following code creates a keymap to toggle inlay hints in your
      -- code, if the language server you are using supports them
      --
      -- This may be unwanted, since they displace some of your code
      if client and client:supports_method('textDocument/inlayHint', event.buf) then
        map('<leader>ti', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
      end
    end,
  })

  -- Enable the following language servers
  --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
  --  See `:help lsp-config` for information about keys and how to configure
  ---@type table<string, vim.lsp.Config>
  local servers = {
    clangd = {},
    pyright = {},
    texlab = {
        settings = {
            texlab = {
              build = {
                  onSave = false,
              },
              -- Use latexindent for formatting
              latexFormatter = "latexindent",

              latexindent = {
                  modifyLineBreaks = false,
              },
            },
        },
    },
    -- Grammar and spelling checking
    ltex_plus = {
        filetypes = { "tex", "plaintex", "markdown" },
        settings = {
            ltex = {
                language = "en-US",
            },
        },
    },
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

  vim.pack.add {
    gh 'neovim/nvim-lspconfig',
    gh 'mason-org/mason.nvim',
    gh 'mason-org/mason-lspconfig.nvim',
    gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
  }

  -- Automatically install LSPs and related tools to stdpath for Neovim
  require('mason').setup {}

  -- Translates between nvim-lspconfig server names and mason.nvim package names (e.g. lua_ls <-> lua-language-server)
  require('mason-lspconfig').setup {
    automatic_enable = false, -- Change this to true if you want to automatically enable servers that are installed manually (e.g. via :Mason / :MasonInstall)
  }

  -- Ensure the servers and tools above are installed
  --
  -- To check the current status of installed tools and/or manually install
  -- other tools, you can run
  --    :Mason
  --
  -- You can press `g?` for help in this menu.
  local ensure_installed = vim.tbl_keys(servers or {})
  vim.list_extend(ensure_installed, {
    -- You can add other tools here that you want Mason to install
  })

  require('mason-tool-installer').setup { ensure_installed = ensure_installed }

  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end
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
  vim.pack.add {
      gh 'micangl/cmp-vimtex',
      {
          src = gh 'saghen/blink.compat',
          version = vim.version.range '2.*',
      },
  }

  require('blink.compat').setup({})
  require('cmp_vimtex').setup({
    -- Use VimTeX's bibliography data instead of cmp-vimtex's faulty async parser.
    bibtex_parser = { enabled = false },
  })

  -- [[ Autocomplete Engine ]]
  vim.pack.add { { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' } }
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
      documentation = { auto_show = false, auto_show_delay_ms = 500 },
    },

    sources = {
      default = { 'lsp', 'path', 'snippets' },
      -- Add VimTeX completion only for LaTeX files
      per_filetype = {
          tex = { 'vimtex', inherit_defaults = true },
      },

      -- Configure the VimTeX completion provider
      providers = {
        vimtex = {
            name = 'vimtex',
            module = 'blink.compat.source',
            min_keyword_length = 0,
        },
      },
    },

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
  -- [[ Configure Treesitter ]]
  --  Used to highlight, edit, and navigate code
  --
  --  See `:help nvim-treesitter-intro`

  -- NOTE: You can also specify a branch or a specific commit
  vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

  -- Ensure basic parsers are installed
  local parsers = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
  require('nvim-treesitter').install(parsers)

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    -- Check if the buffer is valid (might not be after install completes)
    if not vim.api.nvim_buf_is_valid(buf) then return end

    -- Check if a parser exists and load it
    if not vim.treesitter.language.add(language) then return end

    -- Enable syntax highlighting and other treesitter features
    vim.treesitter.start(buf, language)

    -- Enable treesitter based folds
    -- For more info on folds see `:help folds`
    -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    -- vim.wo.foldmethod = 'expr'

    -- Check if treesitter indentation is available for this language, and if so enable it
    -- in case there is no indent query, the indentexpr will fallback to the vim's built in one
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil

    -- Enable treesitter based indentation
    if has_indent_query then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match

      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end

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
  -- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  require 'kickstart.plugins.debug'
  require 'kickstart.plugins.indent_line'
  require 'kickstart.plugins.lint'
  require 'kickstart.plugins.autopairs'
  require 'kickstart.plugins.neo-tree'

  -- NOTE: You can add your own plugins, configuration, etc. in `lua/custom/plugins/*.lua`.
  --
  -- For independent modules, uncomment the convenience loader:
  -- require 'custom.plugins'
  --
  -- `custom.plugins` automatically loads files from that directory, but their
  -- order is unspecified. If plugins depend on each other, keep them in the same
  -- file and put their `vim.pack.add()` and `setup()` calls in the required order.
  --
  -- If separate modules need a specific order, require them explicitly instead:
  -- require 'custom.plugins.colorscheme'
  -- require 'custom.plugins.ui'
  -- require 'custom.plugins.git'
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
  vim.keymap.set('n', '<M-h>', splits.resize_left)
  vim.keymap.set('n', '<M-j>', splits.resize_down)
  vim.keymap.set('n', '<M-k>', splits.resize_up)
  vim.keymap.set('n', '<M-l>', splits.resize_right)

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
end

-- Section 12: Latex integration
do
  -- Plugins
  vim.pack.add {
    gh 'lervag/vimtex',
    gh 'iurimateus/luasnip-latex-snippets.nvim',
  }

  vim.g.vimtex_view_method = "zathura_simple"

  -- Load mathematical LaTeX snippets
  require("luasnip-latex-snippets").setup({
      use_treesitter = false,
      allow_on_markdown = false,
  })

  vim.api.nvim_create_autocmd("FileType", {
        pattern = "tex",
        callback = function(args)
            vim.keymap.set("n", "<leader>lf", function()
                vim.lsp.buf.format({
                    async = true,
                    filter = function(client)
                        return client.name == "texlab"
                    end,
                })
            end, {
                buffer = args.buf,
                desc = "Format LaTeX document",
            })

            -- spell checking
            vim.opt_local.spell = true
            vim.opt_local.spelllang = "en_us"

            -- Line wrapping
            vim.opt_local.wrap = true
            vim.opt_local.linebreak = true

            -- show math symbols as unicode
            vim.opt_local.conceallevel = 2
            vim.opt_local.concealcursor = ""

            -- indentation set to 2 spaces
            -- LaTeX indentation
            vim.opt_local.expandtab = true
            vim.opt_local.shiftwidth = 2
            vim.opt_local.tabstop = 2
            vim.opt_local.softtabstop = 2
        end,
    })

end


-- Pi integration
do
  vim.pack.add { "https://github.com/carderne/pi-nvim" }
  -- require("pi-nvim").setup()
  require("pi-nvim").setup({
    socket_path = nil, -- auto-discover
    set_default_keymaps = true,
  })

  -- vim.keymap.set("n", "<leader>pp", ":PiSend<CR>")
  -- vim.keymap.set("n", "<leader>pf", ":PiSendFile<CR>")
  -- vim.keymap.set("v", "<leader>ps", ":PiSendSelection<CR>")
  -- vim.keymap.set("n", "<leader>pb", ":PiSendBuffer<CR>")
  -- vim.keymap.set("n", "<leader>pi", ":PiPing<CR>")
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
  vim.keymap.set('n', '<leader>ac', '<cmd>ClaudeCode<CR>',
    { desc = 'Toggle Claude Code' })

  vim.keymap.set('n', '<leader>af', '<cmd>ClaudeCodeFocus<CR>',
    { desc = 'Focus Claude Code' })

  vim.keymap.set('n', '<leader>ab', '<cmd>ClaudeCodeAdd %<CR>',
    { desc = 'Add current buffer to Claude' })

  vim.keymap.set('v', '<leader>as', '<cmd>ClaudeCodeSend<CR>',
    { desc = 'Send selection to Claude' })

  vim.keymap.set('n', '<leader>aa', '<cmd>ClaudeCodeDiffAccept<CR>',
    { desc = 'Accept Claude diff' })

  vim.keymap.set('n', '<leader>ad', '<cmd>ClaudeCodeDiffDeny<CR>',
    { desc = 'Reject Claude diff' })
end
