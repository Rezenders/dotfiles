# GNOME shortcut sync

Run as your normal user in a GNOME desktop session. Requires `dconf`
(on Ubuntu, provided by `dconf-cli`).

## Export on the source machine

```bash
bash ~/.config/gnome/shortcuts.sh export

git --git-dir="$HOME/.cfg" --work-tree="$HOME" add \
  .config/gnome/shortcuts.sh .config/gnome/README.md .config/gnome/shortcuts
# Review before committing: custom shortcut commands may contain private data.
git --git-dir="$HOME/.cfg" --work-tree="$HOME" diff --cached
```

Commit and push using your normal dotfiles workflow.

## Apply on another machine

After pulling your dotfiles:

```bash
bash ~/.config/gnome/shortcuts.sh apply
```

The script backs up current settings under
`${XDG_STATE_HOME:-$HOME/.local/state}/gnome-shortcuts/backups/` before loading
snapshots. Backups are not stored with the tracked configuration.
To restore a backup, run `dconf load PATH < FILE` for each file, using the
corresponding GNOME path from `shortcuts.sh`.

## Focus Changer: additional Vim-style shortcuts

Install and enable Focus Changer on both machines. Its settings live under
`/org/gnome/shell/extensions/focus-changer/`, separately from GNOME's built-in
shortcuts. The sync script includes this subtree as `focus-changer.dconf`.
After updating an older checkout, rerun `export` on the source machine to
create this additional snapshot before applying on the destination.

To keep the extension's default Ctrl+Super+arrow bindings and also add
Super+h/j/k/l (left/down/up/right), run:

```bash
dconf write /org/gnome/shell/extensions/focus-changer/focus-left "['<Control><Super>Left', '<Super>h']"
dconf write /org/gnome/shell/extensions/focus-changer/focus-down "['<Control><Super>Down', '<Super>j']"
dconf write /org/gnome/shell/extensions/focus-changer/focus-up "['<Control><Super>Up', '<Super>k']"
dconf write /org/gnome/shell/extensions/focus-changer/focus-right "['<Control><Super>Right', '<Super>l']"
```

These commands replace each direction's shortcut list with the two shown;
include any other custom bindings you want to retain.

GNOME normally reserves Super+h for minimize and Super+l for lock screen.
Inspect their current bindings before changing them:

```bash
gsettings get org.gnome.desktop.wm.keybindings minimize
gsettings get org.gnome.settings-daemon.plugins.media-keys screensaver
```

If they are the defaults, release Super+h and move lock screen to Super+Escape:

```bash
gsettings set org.gnome.desktop.wm.keybindings minimize "[]"
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>Escape']"
```

If those lists contain other bindings you want to keep, remove only the
conflicting entries instead. Check that your replacement lock shortcut works.
If Focus Changer does not pick up the changes immediately, disable and re-enable
it in the Extensions app. Then run `export`, commit/push the snapshots, and
run `apply` on the other machine. The conflict changes above are also captured
by the window-manager and media-keys snapshots.

## Scope and limitations

- Covers window-manager, Shell, Mutter, Wayland Mutter, and media-key settings.
- The media-keys subtree includes custom application shortcuts, their registered
  paths, and other media-key preferences (not only shortcut bindings).
- Includes Focus Changer settings; other extension-specific settings are not included.
  This does not install or enable the extension.
- Exports contain explicitly stored settings, not a full copy of GNOME defaults.
  Empty snapshot files are valid.
- Applying overlays stored settings, without resetting unspecified destination
  settings. In particular, destination-only bindings may remain. The exported
  custom-shortcut list replaces that list when present in the snapshot.
- GNOME versions should be similar, and shortcut commands must be installed on
  each machine. Review machine-specific paths before sharing.
- Changes in GNOME Settings are not exported automatically: rerun `export`,
  review the diff, and commit. Git checkout alone does not apply settings.
- Applying is not transactional across subtrees; on failure, use the printed
  backup path to restore previous values.

Do not track the binary `~/.config/dconf/user` database.
