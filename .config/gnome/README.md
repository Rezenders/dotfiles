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

## Scope and limitations

- Covers window-manager, Shell, Mutter, Wayland Mutter, and media-key settings.
- The media-keys subtree includes custom application shortcuts, their registered
  paths, and other media-key preferences (not only shortcut bindings).
- Extension-specific shortcuts and settings outside these subtrees are not included.
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
