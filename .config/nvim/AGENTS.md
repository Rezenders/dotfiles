# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, etc.) when working with code in this repository.

## Git repository layout

This directory is part of a dotfiles repository stored as a bare Git repository at
`$HOME/.cfg`, with `$HOME` as its working tree. There is intentionally no local
`.git` directory.

For all Git operations, use:

```sh
git --git-dir="$HOME/.cfg" --work-tree="$HOME" <command>
```

Do not run `git init` or create a `.git` file/directory here. Do not rely on shell
aliases such as `config`; agent shells may not load them.

Scope status and diffs to this workspace unless broader inspection is needed
(run these commands from the config directory):

```sh
git --git-dir="$HOME/.cfg" --work-tree="$HOME" status --short -- .
git --git-dir="$HOME/.cfg" --work-tree="$HOME" diff -- .
```

## What this is

A personal Neovim config (Neovim 0.13-dev) derived from kickstart.nvim, using the
**built-in `vim.pack` plugin manager** — not lazy.nvim. Plugins are installed with
`vim.pack.add { gh 'owner/repo' }` (the `gh` helper is defined locally in each file
that needs it) and pinned in `nvim-pack-lock.json`. There is no lazy loading: a plugin's
`vim.pack.add` is followed immediately by its `require(...).setup`.

- Inspect pending updates: `:lua vim.pack.update(nil, { offline = true })`
- Update plugins: `:lua vim.pack.update()` (rewrites `nvim-pack-lock.json`)
- Post-install build steps (LuaSnip `make install_jsregexp`, treesitter `:TSUpdate`) run
  from the `PackChanged` autocmd in `lua/custom/pack_hooks.lua`; add new build hooks there.
  Section 3 of `init.lua` registers it before any `vim.pack.add` calls.
- Health check: `:checkhealth custom` (`lua/custom/health.lua`)

## Architecture

`init.lua` is an explicit sequential table of contents. All modules use `setup()`;
there is no custom plugin-directory loader. **Order matters**:

1. `custom.options` enables the loader, sets leaders/options, and loads native undotree.
2. `custom.keymaps` configures diagnostics and general mappings; `custom.autocmds`
   registers file conveniences, yank highlighting, and whitespace cleanup.
3. `custom.pack_hooks` registers builds before any plugin additions.
4. `custom.plugins.ui`, `editing`, and `git` configure their respective domains.
5. `custom.plugins.search` configures Fzf-lua and its LspAttach mappings before servers start.
6. `custom.plugins.lsp` registers Blink capabilities, merges LaTeX servers, sets up
   Mason, and enables servers. `formatting` then sets up explicit manual formatting;
   `markdown` sets up Markview rendering. These are separate responsibilities.
7. `custom.plugins.completion` initializes LuaSnip, friendly-snippets, the LaTeX
   bridge, then Blink UI. `custom.plugins.treesitter` initializes parsers and features.
8. `custom.plugins.linting` and `file_explorer` initialize nvim-lint and Neo-tree.
   Search and Neo-tree deliberately remain at different startup positions.
9. `custom.integrations.kitty` configures scrollback, images, smart-splits, split
   launch mappings, and calls the existing `custom.kitty_docks.setup()`.
10. Final `custom.latex.setup()` follows LuaSnip; Pi and Claude integrations run last.

UI owns which-key, themes/highlights, icons, indentation/line-length guides, and
mini status displays. Editing owns guess-indent, todo-comments, mini.ai/surround,
and autopairs. Git owns gitsigns, native diff wrapping, diffview, gitlinker, and Git
keymaps. UI/editing share mini.nvim; editing/Git share Plenary; vim.pack deduplicates
repeated dependency additions. Treesitter uses `main`, installs parsers on FileType,
and preserves VimTeX syntax by skipping LaTeX attachment.

The former `lua/kickstart/` modules are integrated by responsibility. Linting keeps
BufEnter/BufWritePost/InsertLeave and the modifiable-only guard. Debugger setup,
keymaps, and Go adapter installation are removed. Cached plugins, their lockfile
pins, and Mason packages remain on disk; inactive DAP plugins are not loaded.

### File conveniences (`lua/custom/file_autocmds.lua`)
`custom.autocmds.setup()` registers cursor restoration and missing-parent-directory handling.
Cursor restoration uses the ShaDa `"` mark, skips special/diff/commit buffers,
and yields to explicit startup commands and cursor movement. Interactive saves
ask before creating parents (default No); headless saves never prompt and require
an explicit `:write!` to create missing parents. URI buffers are excluded.

### LaTeX (`lua/custom/latex/`)
Wired into `init.lua` at three load-order-sensitive points:
`require('custom.latex.lsp').servers()` is merged into the LSP `servers` table in
`lua/custom/plugins/lsp.lua` (texlab +
ltex_plus), `require('custom.latex.completion').setup()` runs in
`custom.plugins.completion` before blink.cmp UI setup, and
`require('custom.latex').setup()` (VimTeX + snippets) runs after LuaSnip. Buffer-local
tex options/keymaps live in `after/ftplugin/tex.lua`. `ltex_extra.lua` is a local
workaround for an upstream ltex_extra.nvim bug — keep the fix here, not in the plugin checkout.

### Kitty docks (`lua/custom/kitty_docks.lua`)
Neovim runs inside kitty and toggles side "dock" windows (Yazi, Claude, Pi) via
`kitten @ launch --type=tab-dock`, tagging them with the user var `nvim_dock`. Hiding a
dock calls `kitty/dock_toggle.py` (a kitten using kitty internal APIs) to park the window
in a hidden `NVIM docks [<id>]` tab and restore it later with its original `DockSpec`,
so the child process keeps running.

### AI integrations
- Claude Code: `custom.integrations.claude` configures `coder/claudecode.nvim`; Claude itself runs as `claude --ide` in a kitty
  dock, not inside Neovim (`<leader>a*` keymaps).
- Pi: `custom.integrations.pi` sets up guarded bindings; optionally loaded from a local fork at `~/git/pi-nvim` (prepended to runtimepath), not from `vim.pack`. Missing/incompatible checkouts warn and skip Pi keymaps; fork URL/revision and bootstrap instructions are in `INTEGRATIONS.md`.
- `lua/custom/runtime.lua` bounds optional desktop appearance queries and dock subprocesses; dock deadlines release busy state independently of process completion.
- `:checkhealth custom` covers workflow tools, configured LSP commands, Kitty remote control and the local Pi checkout.

### Manual formatting (`lua/custom/plugins/formatting.lua`)
`<leader>cf` formats the current editable file buffer asynchronously; `<leader>mf`
is a global alias and `<leader>lf` in tex buffers calls the same entry point.
No format-on-save/after-save hooks are enabled. Conform selects Prettier for
Markdown, StyLua for Lua, `ruff_format` for Python, and RuboCop for Ruby.
`default_format_opts.lsp_format = 'never'` prevents arbitrary LSP fallback;
missing/unsupported tools warn and point to `:ConformInfo`. Python formatting does
not run lint fixes or organize imports. All formatters use project style configs.

Ruby inherits Conform's safe RuboCop autocorrection (`-a`, not unsafe `-A`). With a
Gemfile it prefers executable project `bin/rubocop`, otherwise uses
`bundle exec rubocop` from the Gemfile root; it never silently substitutes the
global version for a bundled project. Outside a bundle it searches for a binstub,
then uses PATH RuboCop. Ruby/Bundler/gems are project-managed, not installed by this
config. The existing global RuboCop launcher was found to reference missing
`/usr/bin/ruby3.0`; repair the Ruby environment before testing standalone Ruby.

LaTeX/plaintex deliberately retains TexLab-only async formatting, preserving
`latexFormatter = 'latexindent'` and `latexindent.modifyLineBreaks = false`.
No attached TexLab means a warning, not a different formatter. StyLua is explicitly
installed as a Mason tool, not enabled as an LSP; Lua LS formatting remains disabled.

### Line-length guide
`lua/custom/plugins/ui.lua` configures `m4xshen/smartcolumn.nvim`: an 80-column fallback (90 for Ruby),
enabled for Markdown/text and disabled for help, with whole-file scope. The guide appears only
when a line exceeds the threshold. EditorConfig `max_line_length` takes precedence;
markdownlint MD013 and LSP settings are not read. Smartcolumn only controls the
visual guide, but Neovim's built-in EditorConfig support can also set `textwidth`
from `max_line_length`, affecting wrapping according to `formatoptions`.

## Tests

Run from the config directory:

```sh
nvim --clean -l tests/startup.lua      # explicit full startup sequence with mocked modules
nvim --clean -l tests/core.lua         # options, keymaps, autocmds, guarded builds and failures
nvim --clean -l tests/navigation.lua   # search, explorer and Markdown bindings
nvim --clean -l tests/formatting.lua   # installed Conform + StyLua/Ruff/Prettier; temp project configs and mocked Ruby/TexLab
nvim --clean -l tests/lsp_tools.lua    # formatter installation vs actual LSP server registration
nvim --clean -l tests/integrations.lua # Kitty/image guard, split launches, Pi/Claude mappings
nvim --clean -l tests/diagnostic_list.lua # diagnostic location-list filtering
nvim --clean -l tests/ui.lua           # installed UI/editing/Git plugins; all four host/appearance combinations
nvim --clean -l tests/smartcolumn.lua   # needs smartcolumn.nvim installed via vim.pack
nvim --clean -l tests/ltex_extra.lua    # needs ltex_extra.nvim installed via vim.pack
nvim --clean -l tests/runtime.lua       # optional integrations and subprocess failure paths
nvim --clean -l tests/completion.lua    # completion options and LuaSnip/LaTeX/Blink startup order
nvim --clean -l tests/treesitter.lua    # async parser attachment, per-window folds, stale callbacks
nvim --clean -l tests/linting.lua       # linter configuration and unchanged automatic event policy
nvim --clean -l tests/health.lua        # health diagnostics with mocked tools/processes
nvim --clean -l tests/file_autocmds.lua # cursor restoration and safe parent-directory creation
kitty +runpy 'import runpy; runpy.run_path("tests/kitty_dock_toggle.py", run_name="__main__")'
```

## Style

Lua is formatted with StyLua through Conform (installed via Mason; no StyLua LSP,
and lua_ls formatting is disabled).
`.stylua.toml` defines the local style; avoid broad formatting passes alongside unrelated changes.
Markdown formatting respects project Prettier settings; its policy is independent of the EditorConfig-based visual guide (see `INTEGRATIONS.md`).
`.luarc.json` targets LuaJIT and disables `missing-fields` diagnostics.

## Explaining changes

When adding or changing configuration in this workspace, always explain what each
parameter means: the option or key itself, the value chosen, and why that value was
picked. This applies to the explanation given to the user, not only to code comments.
