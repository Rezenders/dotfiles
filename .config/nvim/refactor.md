# Incremental Neovim configuration refactor

## Goal

Make the startup sequence easy to navigate without redesigning the configuration,
changing plugin behavior, or adding a loader framework. This is a maintainability
refactor, not a startup-performance optimization.

Keep `init.lua` as an explicit, sequential table of contents. Do not impose a
60–100-line target: visible dependencies matter more than the final line count.

## Principles

- Keep the existing `lua/custom/` namespace and existing LaTeX modules.
- Group by responsibility, not one file per plugin.
- Keep `vim.pack.add` next to the setup that uses those plugins.
- Preserve current startup order during extraction, even when related components
  currently initialize at different points. Reordering is a separate change.
- Move code without changing settings, keymaps, plugin versions, or behavior.
- Use explicit `setup()` entry points, called at the original startup position.
- Keep server tables private unless a real consumer needs them.
- Keep `gh()` local; do not introduce `_G.gh`. A shared helper is optional, not
  required merely to eliminate a tiny repeated function.
- Preserve existing tests and update source-based tests to follow moved code.
- Do not split working modules merely to match a proposed directory tree.

## Progress and next steps

### Done: Kitty dock implementation

The custom dock orchestration lives in `lua/custom/kitty_docks.lua`. Keep this
boundary. Scrollback, image rendering, and smart-splits setup were later extracted
into `custom.integrations.kitty`, which calls the existing dock implementation.

### Done: LSP extraction

Section 6 now calls `require('custom.plugins.lsp').setup()` at its original startup
position. `lua/custom/plugins/lsp.lua` owns Fidget, LspAttach callbacks/keymaps,
the local server table, the LaTeX server merge, Blink capability registration,
Mason/tool installation, health server registration, and server enablement.

Blink UI/snippet setup remains in the completion section. Markdown formatting
and preview setup remain outside the LSP module.

### Done: UI extraction

Section 4 now groups the former interleaved section by responsibility:

1. `custom.plugins.ui.setup()`: which-key, themes/highlights, devicons, and mini
   statusline/statuscolumn/tabline.
2. `custom.plugins.editing.setup()`: guess-indent, todo-comments, mini.ai/surround.
3. `custom.plugins.git.setup()`: gitsigns, native diff wrapping, diffview,
   gitlinker, and Git keymaps.

This is an intentional reordering: UI precedes editing, then Git; all remain
before navigation. Options, keymaps, plugin versions, theme selection, and
highlight behavior are preserved. UI and editing each declare mini.nvim so their
dependencies are explicit; vim.pack deduplicates the repeated addition. Editing
also declares Plenary for todo-comments search instead of relying on the later
Git module's Plenary addition.
Which-key's Git group labels stay in UI; actual Git mappings live in Git.
`tests/ui.lua` exercises the sequence with installed plugins across personal/work
and dark/light combinations, including editing options and Git/diff behavior.

### Done: Kickstart integration and debugger removal

The former `lua/kickstart/` modules are integrated into the existing domains:

- Indent-blankline and smartcolumn live in `custom.plugins.ui`.
- Autopairs lives in `custom.plugins.editing`.
- Linting lives in `custom.plugins.linting`, called in Section 10 at its former
  position, with unchanged Markdown configuration, events, and modifiable guard.
- Health checks live in `custom.health`; use `:checkhealth custom`. LSP server
  registration and tests use the new module path.

UI guides and autopairs now initialize earlier with their owning modules, before
navigation. No optional behavior suggestions were applied: indent-guide and
autopairs defaults and lint policy remain unchanged.

Debugging was removed at the user's request: no DAP module/keymaps, Go adapter
setup, or Go/Delve health checks remain. Existing installed plugins, their vim.pack
lock entries, and Mason packages are retained: vim.pack's lockfile tracks installed
plugins, including inactive ones. No uninstall or unrelated plugin updates are
performed. Tests cover the moved setup and defaults.

### Done: completion and Treesitter extraction

Sections 8 and 9 now call `custom.plugins.completion.setup()` and
`custom.plugins.treesitter.setup()` at their original startup positions.

- Completion owns LuaSnip, friendly-snippets, the LaTeX completion bridge, and
  Blink UI/snippet setup. Blink registration and capabilities remain in LSP.
- Treesitter owns parser installation, highlighting, per-window folding,
  indentation, FileType attachment, and stale async callback handling.
- Options, plugin versions, parser lists, callbacks, and execution order are
  unchanged. LaTeX completion still precedes Blink UI setup; final LaTeX setup
  still follows LuaSnip and Treesitter.
- `tests/completion.lua` covers sequencing and options; `tests/treesitter.lua`
  now exercises the module directly rather than extracting a block from init.lua.

### Follow-up: consistent manual formatting

After the extraction, formatting was expanded without changing save behavior:
`<leader>cf` is the shared asynchronous command; `<leader>mf` and tex-local
`<leader>lf` are aliases. Conform handles Markdown/Prettier, Lua/StyLua,
Python/Ruff formatting, and Ruby/RuboCop (project binstub or Bundler preferred).
LaTeX keeps its existing TexLab/latexindent route and no-reflow setting. Arbitrary
LSP fallback is disabled; missing tools warn. StyLua remains a Mason-installed tool
but is no longer a language server. See AGENTS.md for policy and tests.

### Done: remaining domain and core extractions

`init.lua` is now a sequential table of contents. All remaining inline blocks were
extracted without changing option values, plugin versions, keymaps, or guards:

- `custom.options`, `custom.keymaps`, and `custom.autocmds` own core settings,
  diagnostic/general mappings, and file/yank/whitespace autocommands.
- `custom.pack_hooks` registers the existing LuaSnip and Treesitter build hooks
  before any plugin additions. Helpers remain local; no global gh function exists.
- `custom.plugins.search` owns Fzf-lua; `custom.plugins.file_explorer` owns Neo-tree.
  They retain their distinct startup positions; no phased navigation module needed.
- `custom.plugins.formatting` owns Conform; `custom.plugins.markdown` owns Markview.
  Formatting and rendering still initialize consecutively at their original position.
- `custom.integrations.kitty` owns the remaining Kitty setup and calls the existing
  dock implementation. `pi` and `claude` own their respective setup and mappings.
- All plugin and external-integration startup order is preserved. Within core setup,
  undo/comment/buffer-close mappings are grouped with other keymaps before registering
  autocommands; these mappings have no dependency on those autocommands.
- `tests/startup.lua` covers the full orchestration. Core, navigation, and integration
  tests cover moved behavior with plugin/process mocks; existing regression tests
  continue to cover deeper subsystems.

Current structure:

```text
init.lua
lua/custom/
├── options.lua                 # Core options and native undo support
├── keymaps.lua                 # General mappings and diagnostic policy
├── autocmds.lua                # File conveniences, yank, whitespace cleanup
├── pack_hooks.lua              # LuaSnip/Treesitter builds
├── plugins/
│   ├── lsp.lua                 # Extracted
│   ├── ui.lua                  # Interface and appearance
│   ├── editing.lua             # Editing and source annotations
│   ├── git.lua                 # Git workflows
│   ├── linting.lua             # Automatic linting
│   ├── completion.lua          # Snippets, LaTeX bridge, Blink UI
│   ├── treesitter.lua          # Parsers, highlighting, folding, indentation
│   ├── search.lua              # Fzf-lua and LSP pickers
│   ├── file_explorer.lua       # Neo-tree
│   ├── formatting.lua          # Conform
│   └── markdown.lua            # Markview rendering
├── integrations/
│   ├── kitty.lua               # Scrollback, images, splits, calls docks
│   ├── pi.lua                  # Optional fork and bindings
│   └── claude.lua              # External terminal integration
├── kitty_docks.lua             # Already extracted
├── latex/                      # Keep existing structure
├── file_autocmds.lua
├── health.lua                  # :checkhealth custom
└── runtime.lua
```

The planned extractions are complete. The existing LaTeX, runtime, file conveniences,
health, and dock implementations remain in their established modules. Remaining
verification is interactive startup and representative real workflows; headless
and mocked tests do not replace live server, picker, or Kitty/AI integration checks.

## Startup invariants

1. Core options and leader keys precede plugin/keymap configuration that uses them.
2. `PackChanged` build hooks are registered before plugin additions.
3. LaTeX servers are merged before Mason setup and server enablement.
4. Blink is loaded and its capabilities registered before enabling LSP servers;
   its UI/snippet setup remains later in the completion section.
5. LaTeX completion setup runs before Blink UI setup.
6. Final LaTeX setup runs after LuaSnip.
7. Existing optional integration guards and failure handling remain intact.

## Verification for each extraction

- Review the diff for move-only changes and unintended startup reordering.
- Check Lua syntax and LSP diagnostics where available.
- Run the smallest relevant regression tests. For the LSP extraction:

  ```sh
  nvim --clean -l tests/lsp_capabilities.lua
  nvim --clean -l tests/lsp_highlights.lua
  nvim --clean -l tests/inlay_hints.lua
  nvim --clean -l tests/health.lua
  ```

  The capability test requires the installed Blink plugin.
- Check normal interactive startup and representative workflows when possible;
  mocked/headless tests are not a substitute for an actual server connection.
- Update this roadmap and `AGENTS.md` when module boundaries change.
