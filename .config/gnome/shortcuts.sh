#!/usr/bin/env bash
# Sync GNOME keybindings through text snapshots stored alongside this script.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
settings_dir="$script_dir/shortcuts"
names=(window-manager shell mutter mutter-wayland media-keys)
paths=(
  /org/gnome/desktop/wm/keybindings/
  /org/gnome/shell/keybindings/
  /org/gnome/mutter/keybindings/
  /org/gnome/mutter/wayland/keybindings/
  /org/gnome/settings-daemon/plugins/media-keys/
)

usage() {
  printf '%s\n' \
    "Usage: $0 export|apply" \
    '' \
    'export  Save current settings to ~/.config/gnome/shortcuts/*.dconf.' \
    'apply   Back up current settings, then load those snapshots.' \
    '' \
    'Run as your normal user inside a GNOME desktop session.' \
    'The media-keys snapshot includes custom shortcuts and media-key preferences.' \
    'Applying overlays settings; it does not reset unlisted destination settings.'
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  export|apply) action="$1" ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -eq 1 ]] || { usage >&2; exit 2; }
command -v dconf >/dev/null || { printf 'Required command not found: dconf\n' >&2; exit 1; }
[[ "$EUID" -ne 0 ]] || { printf 'Run this script as your normal desktop user, not root.\n' >&2; exit 1; }

# Capture every subtree before replacing any existing snapshot.
export_to() {
  local destination="$1" temporary i
  mkdir -p -- "$destination"
  temporary="$(mktemp -d "$destination/.export.XXXXXX")"
  for i in "${!names[@]}"; do
    if ! dconf dump "${paths[$i]}" > "$temporary/${names[$i]}.dconf"; then
      rm -rf -- "$temporary"
      return 1
    fi
  done
  for i in "${!names[@]}"; do
    mv -- "$temporary/${names[$i]}.dconf" "$destination/${names[$i]}.dconf"
  done
  rmdir -- "$temporary"
}

if [[ "$action" == export ]]; then
  export_to "$settings_dir"
  printf 'Exported GNOME shortcut settings to %s\n' "$settings_dir"
else
  # Check all inputs before making any changes. Empty files are valid dumps.
  for name in "${names[@]}"; do
    [[ -f "$settings_dir/$name.dconf" && -r "$settings_dir/$name.dconf" ]] || {
      printf 'Missing or unreadable snapshot: %s/%s.dconf\nRun export on the source machine first.\n' "$settings_dir" "$name" >&2
      exit 1
    }
  done
  backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/gnome-shortcuts/backups"
  mkdir -p -- "$backup_root"
  backup_dir="$(mktemp -d "$backup_root/$(date +%Y%m%d-%H%M%S).XXXXXX")"
  export_to "$backup_dir"
  printf 'Current settings backed up to %s\n' "$backup_dir"
  for i in "${!names[@]}"; do
    if ! dconf load "${paths[$i]}" < "$settings_dir/${names[$i]}.dconf"; then
      printf 'Apply failed at %s; earlier subtrees may already be applied. Backup: %s\n' "${names[$i]}" "$backup_dir" >&2
      exit 1
    fi
  done
  printf 'Applied GNOME shortcut settings.\n'
fi
