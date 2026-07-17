#!/usr/bin/env bash
#
# ohmagub :: uninstall.sh — undo ohmagub's own artifacts. Does NOT remove
# installed packages, your dotfiles, or the checkout (those are yours to keep).

set -euo pipefail
export OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Uninstalling ohmagub (config-level)"

# CLI + state
rm -f "$HOME/.local/bin/ohmagub"
ok "removed ohmagub CLI symlink"

# Disable the GNOME extensions ohmagub enabled (leaves them installed).
if has gnome-extensions; then
  for uuid in "${OHMAGUB_GNOME_EXTENSIONS[@]}" "auto-move-windows@gnome-shell-extensions.gcampax.github.com"; do
    gnome-extensions disable "$uuid" >/dev/null 2>&1 || true
  done
  ok "disabled ohmagub GNOME extensions"
fi

# Reset the app-to-workspace assignment list.
if has gsettings; then
  gsettings reset org.gnome.shell.extensions.auto-move-windows application-list >/dev/null 2>&1 || true
fi

warn "Left in place: installed packages, your dotfiles ($OHMAGUB_DOTFILES_PATH), and this checkout."
warn "Your keybindings/workspaces remain set — reset via GNOME Settings if desired."
ok "ohmagub artifacts removed. Log out/in to settle GNOME."
