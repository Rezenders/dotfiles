#!/usr/bin/env bash

update_wallpaper() {
  theme=$(gsettings get org.gnome.desktop.interface color-scheme)

  if [[ "$theme" == *prefer-dark* ]]; then
    folder="/$HOME/Pictures/wallpapers/dark-theme"
  else
    folder="$HOME/Pictures/wallpapers/light-theme"
  fi

  gsettings set org.gnome.shell.extensions.wallshuffle folder "$folder"
}

update_wallpaper

gsettings monitor org.gnome.desktop.interface color-scheme |
while read -r _; do
  update_wallpaper
done
