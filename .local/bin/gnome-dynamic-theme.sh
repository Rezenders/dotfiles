#!/usr/bin/env bash

# Configure your GNOME Shell themes
LIGHT_THEME="Flat-Remix-Light-fullPanel"
DARK_THEME="Flat-Remix-Dark"

update_theme() {
  local scheme theme

  scheme=$(gsettings get org.gnome.desktop.interface color-scheme)

  if [[ "$scheme" == "'prefer-dark'" ]]; then
    theme="$DARK_THEME"
  else
    theme="$LIGHT_THEME"
  fi

  # Update GNOME Shell theme
  gsettings set org.gnome.shell.extensions.user-theme name "$theme"
}

# Apply theme at startup
update_theme

# Monitor light/dark mode changes
gsettings monitor org.gnome.desktop.interface color-scheme |
while IFS= read -r _; do
  update_theme
done
