# Local integration and formatting policy

## Optional Pi development fork

Neovim uses `~/git/pi-nvim`, not a `vim.pack` copy. A missing checkout or
failed module/setup call produces a warning and skips Pi keymaps, without
preventing later configuration (including Claude Code) from loading.
A plugin that fails midway through setup may already have registered its own
commands/autocmds; restart Neovim after repairing the checkout.

Known source revision when this configuration was reviewed:

- Fork: <https://github.com/Rezenders/pi-nvim>
- Commit: `c61dee7932beef9aab60c463b34235f1e858df13`
- Package version: `0.2.6`
- Declared Pi peer compatibility: `^0.87.0 || ^1.0.0`

For a new machine (do not overwrite an existing development checkout):

```sh
git clone https://github.com/Rezenders/pi-nvim.git ~/git/pi-nvim
git -C ~/git/pi-nvim checkout c61dee7932beef9aab60c463b34235f1e858df13
```

Configure the Pi agent to load the extension from this same checkout, following
that fork's README. Neovim's runtimepath does not configure the agent extension.
The recorded commit is a reproduction reference, not an enforced pin: local
fork development remains supported. Update this reference when adopting a new
required fork revision. Agent versions and Mason-installed executables are not
pinned by `nvim-pack-lock.json`.

Use `:checkhealth kickstart` for checkout/tool diagnostics and `:PiPing` for
live session connectivity. Health checks do not submit prompts or launch docks.

## Desktop appearance and docks

Desktop appearance queries run only in a local, attached UI with a display and
`gdbus` available. They have a 300 ms timeout; failures, headless instances, and
SSH sessions use the existing light theme (`onehalflight`). Kitty remote-control
commands for dock toggles have a 5 s timeout. Spawn errors, nonzero exits,
timeouts and callback errors clear the busy flag so the next toggle can retry.

## Formatting and lint policy

Markdown formatting is manual (`<leader>mf`) and uses Conform's standard Prettier
formatter without forced `--print-width` or `--prose-wrap` arguments. Project
Prettier configuration therefore takes precedence; absent project settings,
Prettier's defaults apply (including preserving prose wrapping). The visual
column guide independently follows markdownlint MD013. In projects that want
reflow, set `proseWrap: "always"` and a `printWidth` aligned with MD013 in the
project's Prettier config. Neither tool's configuration is silently rewritten.

`.stylua.toml` declares two-space indentation, preferred single quotes, optional
call parentheses, compact simple statements and a 160-column layout, matching
the dominant Kickstart-derived style. Existing Lua has not been broadly
reformatted: format touched/new files deliberately to avoid unrelated churn.

`nvim-web-devicons` is the sole icon provider; MiniIcons' compatibility mock is
not enabled. The lockfile retains only plugins requested by the active config.
On this Neovim build, manually deleting entries while their managed checkouts
remain installed makes `vim.pack` restore the entries at startup. When pruning
again, use `vim.pack.del` on inactive plugins, or archive their directories
outside `site/pack/core/opt` before removing the lock entries. The historical
checkouts removed during this review were preserved under
`~/.local/share/nvim/inactive-pack-archive-20261108-185425/`.
