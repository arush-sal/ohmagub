#!/usr/bin/env bash
#
# ohmagub phase: gnome — desktop settings, 9 workspaces, per-workspace app
# assignment (Auto Move Windows), omakub extensions, i3-style keybindings,
# and your terminal dconf profile.

set -euo pipefail
OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Phase: gnome"
[ "${OHMAGUB_INSTALL_DESKTOP:-1}" = "1" ] || { warn "OHMAGUB_INSTALL_DESKTOP=0 — skipping"; exit 0; }
ensure_sudo
if ! has gnome-shell; then
  warn "GNOME not detected — gsettings/extension steps will be limited"
fi
REPO="$OHMAGUB_DOTFILES_PATH"

# ===========================================================================
# 1. General desktop settings (from setup.sh dconf + sensible defaults)
# ===========================================================================
log "GNOME settings"
gset org.gnome.desktop.interface color-scheme 'prefer-dark'
gset org.gnome.desktop.interface gtk-theme 'Yaru-dark'
gset org.gnome.desktop.interface clock-show-weekday true
gset org.gnome.desktop.interface show-battery-percentage true
gset org.gnome.desktop.interface enable-hot-corners false
# input (setup.sh:251-252)
gset org.gnome.desktop.peripherals.touchpad natural-scroll false
gset org.gnome.desktop.peripherals.touchpad tap-to-click true
# dock — the Ubuntu "sidebar". Disable it for a tiling workflow, or (if you
# keep it: OHMAGUB_DISABLE_DOCK=0) just autohide it.
if [ "${OHMAGUB_DISABLE_DOCK:-1}" = "1" ]; then
  if has gnome-extensions; then
    for d in ubuntu-dock@ubuntu.com dash-to-dock@micxgx.gmail.com; do
      gnome-extensions disable "$d" >/dev/null 2>&1 && step "disabled dock: $d" || true
    done
  fi
  ok "Ubuntu dock (sidebar) disabled — effective after logout"
else
  gset org.gnome.shell.extensions.dash-to-dock autohide true
  gset org.gnome.shell.extensions.dash-to-dock intellihide true
fi
# nautilus
gset org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gset org.gnome.nautilus.preferences show-hidden-files true

# ===========================================================================
# 2. Nine static workspaces
# ===========================================================================
log "Workspaces: ${OHMAGUB_WORKSPACES} (static)"
gset org.gnome.mutter dynamic-workspaces false
gset org.gnome.desktop.wm.preferences num-workspaces "${OHMAGUB_WORKSPACES}"

# ===========================================================================
# 3. i3-style keybindings (Super+1..9 switch, Super+Shift+1..9 move)
# ===========================================================================
log "Keybindings"
wm='org.gnome.desktop.wm.keybindings'
for i in $(seq 1 "${OHMAGUB_WORKSPACES}"); do
  gset "$wm" "switch-to-workspace-$i" "['<Super>$i']"
  gset "$wm" "move-to-workspace-$i"   "['<Super><Shift>$i']"
done
gset "$wm" close             "['<Super><Shift>q']"
gset "$wm" toggle-fullscreen "['<Super>f']"
gset "$wm" toggle-maximized  "['<Super>Up']"

# custom launchers: Super+Return -> terminal, Super+E -> files
base='org.gnome.settings-daemon.plugins.media-keys'
root='/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings'
gset "$base" custom-keybindings "['$root/custom0/', '$root/custom1/']"
_custom() {
  local p="$base.custom-keybinding:$root/custom$1/"
  gsettings set "$p" name "$2" 2>/dev/null || true
  gsettings set "$p" command "$3" 2>/dev/null || true
  gsettings set "$p" binding "$4" 2>/dev/null || true
}
if is_desktop; then
  _custom 0 "Terminal" "gnome-terminal" "<Super>Return"
  _custom 1 "Files" "nautilus" "<Super>e"
fi

# ===========================================================================
# 4. Extensions: omakub set + Auto Move Windows (per-workspace apps)
# ===========================================================================
log "Extensions"
# gnome-shell-extensions provides auto-move-windows; manager + gext to install the rest.
apt_install gnome-shell-extensions gnome-shell-extension-manager pipx
pipx install gnome-extensions-cli >/dev/null 2>&1 || pipx upgrade gnome-extensions-cli >/dev/null 2>&1 || true
export PATH="$HOME/.local/bin:$PATH"

for uuid in "${OHMAGUB_GNOME_EXTENSIONS[@]}"; do
  step "install $uuid"
  gext install "$uuid" >/dev/null 2>&1 || warn "  no EGO build for $uuid on this GNOME yet — skipped"
done
# enable everything we installed + auto-move-windows
for uuid in "${OHMAGUB_GNOME_EXTENSIONS[@]}"; do gnome-extensions enable "$uuid" >/dev/null 2>&1 || true; done
gnome-extensions enable "auto-move-windows@gnome-shell-extensions.gcampax.github.com" >/dev/null 2>&1 || true

# Auto Move Windows: build application-list from the workspace map.
if [ "${#OHMAGUB_WORKSPACE_APPS[@]}" -gt 0 ]; then
  applist="["
  for ws in $(printf '%s\n' "${!OHMAGUB_WORKSPACE_APPS[@]}" | sort -n); do
    applist+="'${OHMAGUB_WORKSPACE_APPS[$ws]}:$ws', "
  done
  applist="${applist%, }]"
  gset org.gnome.shell.extensions.auto-move-windows application-list "$applist"
  ok "workspace app assignments: $applist"
fi

# Tactile gap size (schema ships inside the extension).
tactile_schema="$HOME/.local/share/gnome-shell/extensions/tactile@lundal.io/schemas"
if [ -d "$tactile_schema" ]; then
  gsettings --schemadir "$tactile_schema" set org.gnome.shell.extensions.tactile gap-size "${OHMAGUB_TILING_GAPS}" 2>/dev/null || true
fi
# Space Bar: show workspace numbers, keep empty ones visible.
spacebar_schema="$HOME/.local/share/gnome-shell/extensions/space-bar@luchrioh/schemas"
if [ -d "$spacebar_schema" ]; then
  gsettings --schemadir "$spacebar_schema" set org.gnome.shell.extensions.space-bar.behavior show-empty-workspaces true 2>/dev/null || true
fi

# ===========================================================================
# 5. Terminal profile (loaded verbatim — the su custom-command is intentional)
# ===========================================================================
# GNOME 48 ships Console/Ptyxis by default; your whole terminal setup (dconf
# profile, x-terminal-emulator, Super+Return) targets gnome-terminal, so ensure
# it's installed — this also provides the Terminal.Legacy.Settings schema.
apt_install gnome-terminal
unset _gschemas   # invalidate gset's schema cache — gnome-terminal just added one
if [ -f "$REPO/gnome/gnome-terminal-profiles.dconf" ] && is_desktop; then
  step "loading your GNOME Terminal profile"
  dconf load /org/gnome/terminal/legacy/profiles:/ < "$REPO/gnome/gnome-terminal-profiles.dconf"
  gset org.gnome.Terminal.Legacy.Settings default-show-menubar false
  ok "terminal profile loaded"
else
  warn "no gnome-terminal-profiles.dconf in your dotfiles — skipping terminal profile"
fi

ok "Phase gnome complete"
echo "${_c_dim}   LOG OUT and back in to activate extensions, workspace assignments, and keybindings.${_c_reset}"
