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
  from the `PackChanged` autocmd in Section 3 of `init.lua`; add new build hooks there.
- Health check: `:checkhealth kickstart`

## Architecture

`init.lua` is a single large file split into numbered `SECTION` banners, each wrapped in
a `do ... end` block to scope locals. **Order matters**: later sections depend on earlier
ones (e.g. `gh` is defined after Section 3; LSP `servers` must exist before Mason setup;
LaTeX completion must be set up before `blink.cmp`).

- Sections 1–9: options, keymaps/autocmds, `vim.pack` build hooks, UI plugins, fzf-lua,
  LSP (Mason + `vim.lsp.enable`, servers in a `servers` table), conform (markdown only,
  manual via `<leader>mf`), blink.cmp + LuaSnip, treesitter (`main` branch, parsers
  auto-installed on FileType).
- Section 10+: optional modules (`lua/kickstart/plugins/*`), neo-tree, kitty integration
  (smart-splits, kitty-scrollback, image.nvim, dock panes), LaTeX, Pi, Claude Code.
- Neo-tree is configured inline in Section 10 of `init.lua`; there is no custom plugin-directory loader.

### File conveniences (`lua/custom/file_autocmds.lua`)
Section 2 registers cursor restoration and missing-parent-directory handling.
Cursor restoration uses the ShaDa `"` mark, skips special/diff/commit buffers,
and yields to explicit startup commands and cursor movement. Interactive saves
ask before creating parents (default No); headless saves never prompt and require
an explicit `:write!` to create missing parents. URI buffers are excluded.

### LaTeX (`lua/custom/latex/`)
Wired into `init.lua` at three load-order-sensitive points:
`require('custom.latex.lsp').servers()` is merged into the LSP `servers` table (texlab +
ltex_plus), `require('custom.latex.completion').setup()` runs before blink.cmp, and
`require('custom.latex').setup()` (VimTeX + snippets) runs after LuaSnip. Buffer-local
tex options/keymaps live in `after/ftplugin/tex.lua`. `ltex_extra.lua` is a local
workaround for an upstream ltex_extra.nvim bug — keep the fix here, not in the plugin checkout.

### Kitty docks
Neovim runs inside kitty and toggles side "dock" windows (Yazi, Claude, Pi) via
`kitten @ launch --type=tab-dock`, tagging them with the user var `nvim_dock`. Hiding a
dock calls `kitty/dock_toggle.py` (a kitten using kitty internal APIs) to park the window
in a hidden `NVIM docks [<id>]` tab and restore it later with its original `DockSpec`,
so the child process keeps running.

### AI integrations
- Claude Code: `coder/claudecode.nvim`; Claude itself runs as `claude --ide` in a kitty
  dock, not inside Neovim (`<leader>a*` keymaps).
- Pi: optionally loaded from a local fork at `~/git/pi-nvim` (prepended to runtimepath), not from `vim.pack`. Missing/incompatible checkouts warn and skip Pi keymaps; fork URL/revision and bootstrap instructions are in `INTEGRATIONS.md`.
- `lua/custom/runtime.lua` bounds optional desktop appearance queries and dock subprocesses; dock deadlines release busy state independently of process completion.
- `:checkhealth kickstart` covers workflow tools, configured LSP commands, Kitty remote control and the local Pi checkout.

### Markdown line-length guide
`lua/custom/line_length.lua` sets `colorcolumn` from the project's markdownlint MD013
config. It only works when nvim-lint uses `markdownlint` with the default `--stdin` args,
and shells out to `markdown_line_length.cjs`, which resolves markdownlint's own config
reader from the installed CLI. It is a visual guide only — it never changes `textwidth`.

## Tests

Run from the config directory:

```sh
nvim --clean -l tests/line_length.lua   # needs markdownlint (Mason or PATH) + node
nvim --clean -l tests/ltex_extra.lua    # needs ltex_extra.nvim installed via vim.pack
nvim --clean -l tests/runtime.lua       # optional integrations and subprocess failure paths
nvim --clean -l tests/health.lua        # health diagnostics with mocked tools/processes
nvim --clean -l tests/file_autocmds.lua # cursor restoration and safe parent-directory creation
kitty +runpy 'import runpy; runpy.run_path("tests/kitty_dock_toggle.py", run_name="__main__")'
```

## Style

Lua is formatted with stylua (installed via Mason; lua_ls formatting is disabled).
`.stylua.toml` defines the local style; avoid broad formatting passes alongside unrelated changes.
Markdown formatting respects project Prettier settings; its policy is independent of the MD013 visual guide (see `INTEGRATIONS.md`).
`.luarc.json` targets LuaJIT and disables `missing-fields` diagnostics.

## Explaining changes

When adding or changing configuration in this workspace, always explain what each
parameter means: the option or key itself, the value chosen, and why that value was
picked. This applies to the explanation given to the user, not only to code comments.
