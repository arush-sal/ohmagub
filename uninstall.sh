#!/usr/bin/env bash
#
# omagub :: uninstall.sh — undo omagub's own artifacts. Does NOT remove
# installed packages, your dotfiles, or the checkout (those are yours to keep).

set -euo pipefail
export OMAGUB_PATH="${OMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$OMAGUB_PATH/lib/helpers.sh"
source "$OMAGUB_PATH/config.sh"

log "Uninstalling omagub (config-level)"

# CLI + state
rm -f "$HOME/.local/bin/omagub"
ok "removed omagub CLI symlink"

# Disable the GNOME extensions omagub enabled (leaves them installed).
if has gnome-extensions; then
  for uuid in "${OMAGUB_GNOME_EXTENSIONS[@]}" "auto-move-windows@gnome-shell-extensions.gcampax.github.com"; do
    gnome-extensions disable "$uuid" >/dev/null 2>&1 || true
  done
  ok "disabled omagub GNOME extensions"
fi

# Reset the app-to-workspace assignment list.
if has gsettings; then
  gsettings reset org.gnome.shell.extensions.auto-move-windows application-list >/dev/null 2>&1 || true
fi

warn "Left in place: installed packages, your dotfiles ($OMAGUB_DOTFILES_PATH), and this checkout."
warn "Your keybindings/workspaces remain set — reset via GNOME Settings if desired."
ok "omagub artifacts removed. Log out/in to settle GNOME."
