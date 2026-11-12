-- Explicit startup order: options/leaders, core behavior, then plugin setup.
require('custom.options').setup()

-- ============================================================
-- SECTION 2: KEYMAPS & AUTOCMDS
-- ============================================================
require('custom.keymaps').setup()
require('custom.autocmds').setup()

-- ============================================================
-- SECTION 3: PLUGIN BUILD HOOKS
-- Register before any vim.pack.add calls.
-- ============================================================
require('custom.pack_hooks').setup()

-- ============================================================
-- SECTION 4: UI, EDITING & GIT
-- ============================================================
require('custom.plugins.ui').setup()
require('custom.plugins.editing').setup()
require('custom.plugins.git').setup()

-- ============================================================
-- SECTION 5: SEARCH & NAVIGATION
-- Fzf-lua attaches its LSP mappings before servers are enabled.
-- ============================================================
require('custom.plugins.search').setup()

-- ============================================================
-- SECTION 6: LSP
-- Blink capabilities are registered before enabling servers.
-- ============================================================
require('custom.plugins.lsp').setup()

-- Manual multi-language formatting, followed by Markdown rendering.
require('custom.plugins.formatting').setup()
require('custom.plugins.markdown').setup()

-- ============================================================
-- SECTION 8: AUTOCOMPLETE & SNIPPETS
-- LuaSnip and the LaTeX bridge precede Blink UI setup.
-- ============================================================
require('custom.plugins.completion').setup()

-- ============================================================
-- SECTION 9: TREESITTER
-- ============================================================
require('custom.plugins.treesitter').setup()

-- ============================================================
-- SECTION 10: LINTING & FILE EXPLORER
-- Neo-tree remains later than Fzf-lua to preserve startup order.
-- ============================================================
require('custom.plugins.linting').setup()
require('custom.plugins.file_explorer').setup()

-- Kitty scrollback, images, smart-splits, and existing dock orchestration.
require('custom.integrations.kitty').setup()

-- Final LaTeX setup must follow LuaSnip; servers and completion were wired above.
require('custom.latex').setup()

-- Optional Pi fork and Claude's external Kitty-pane integration.
require('custom.integrations.pi').setup()
require('custom.integrations.claude').setup()
