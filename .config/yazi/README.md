# Yazi integration

## Packages

Smart enter:

```bash
ya pkg add yazi-rs/plugins:smart-enter
```

Jump to char:

```bash
ya pkg add yazi-rs/plugins:jump-to-char
```

Themes:

```bash
ya pkg add marcosvnmelo/kanagawa-dragon
```

Bat as previewer:

```bash
ya pkg add CColombus/bat
```

Grid view:

```bash
ya pkg add skylightlim/gridview
```

chmod:

```bash
ya pkg add yazi-rs/plugins:chmod
```

git browse:

```bash
ya pkg add larry-oates/open-git-remote
```

kdeconnect:

```bash
ya pkg add Deepak22903/kdeconnect-send
```

fullborder:

```bash
ya pkg add yazi-rs/plugins:full-border
```

starship:

```bash
ya pkg add Rolv-Apneseth/starship
```

## Editing

`yazi.toml` runs `python3 "${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/scripts/edit-in-nvim"`
with the selected paths. Python 3 and Neovim must be on PATH. `block = true` lets a
standalone editor use Yazi's terminal until it exits; a successful remote open
returns immediately.

The Neovim dock supplies `NVIM_SERVER` and `NVIM_KITTY_WINDOW_ID`. The helper:

1. Checks server responsiveness, then opens files using checked `--remote-expr`
   RPC. Unlike `--remote`, this never silently starts a local editor on a lost
   connection. Paths are made absolute (the server can have a different cwd),
   encoded as data, and escaped with Neovim's `fnameescape`.
2. Returns focus to the owning Kitty window. A focus error warns but does not
   open another editor, because the files have already opened successfully.
3. Falls back to standalone `nvim -- <files>` if no server is configured or RPC
   fails. The child drops stale server/owner variables so a nested Yazi won't
   target the old editor. Standalone Neovim's exit status is returned.

Each RPC/focus call has a **2-second timeout** so a stale/unresponsive server or
terminal cannot indefinitely block the opener. The interactive fallback has no
timeout. A remote timeout is inherently ambiguous: a busy server may finish
opening files after the helper falls back. The helper never kills the server or
closes its buffers.

Tests (including a temporary, clean, real Neovim RPC server):

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s ~/.config/yazi/tests -v
```

## Appearance

`theme.toml` selects **Catppuccin Latte** for light mode and **Catppuccin Mocha**
for dark mode. Both are pinned in `package.toml`; `ya pkg install` restores them
on another machine. The existing Gruvbox Light dependency is retained.

Kitty controls desktop-driven light/dark changes via its `*-theme.auto.conf`
files. The installed Yazi supports live terminal appearance notifications, so no
custom watcher or desktop polling is needed. Restart an existing Yazi instance
after changing these configuration files.

Neovim keeps its host-specific Kanagawa/Gruvbox palettes but follows terminal
background reports through `custom.appearance`. This synchronizes light/dark
mode, not the exact palette across all three applications.
