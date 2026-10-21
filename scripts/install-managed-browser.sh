#!/usr/bin/env bash
# Sourced by bootstrap. Upgrade the known legacy helper, preserve private variants.
install_managed_browser() {
  local source="$1" target="$2" current=""
  # A private symlink is customization too; never follow it for installation.
  if [ -L "$target" ]; then
    return 0
  fi
  if [ -f "$target" ]; then
    current="$(sha256sum "$target")"
    current="${current%% *}"
  fi
  if [ ! -e "$target" ] || [ "$current" = d725e9f207857c7d689842285d88682c8d69ff3a599290869d0169dab31801bf ]; then
    cp "$source" "$target"
    chmod +x "$target"
  fi
}
