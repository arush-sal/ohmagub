#!/usr/bin/env bash
#
# ohmagub phase: apps — GUI applications (from OHMAGUB_DESKTOP_APPS) + fonts.
# Each app is a case below; add/remove by editing the list in config.sh.

set -euo pipefail
OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Phase: apps"
[ "${OHMAGUB_INSTALL_DESKTOP:-1}" = "1" ] || { warn "OHMAGUB_INSTALL_DESKTOP=0 — skipping GUI apps"; exit 0; }
ensure_sudo

install_app() {
  case "$1" in
    chrome)
      if ! is_installed google-chrome-stable; then
        step "Google Chrome"
        fetch https://dl.google.com/linux/linux_signing_key.pub /tmp/chrome.key
        sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg < /tmp/chrome.key && rm -f /tmp/chrome.key
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
          | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
        apt_dirty; apt_install google-chrome-stable
      fi
      sudo update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/google-chrome-stable 100 >/dev/null 2>&1 || true
      sudo update-alternatives --set x-www-browser /usr/bin/google-chrome-stable >/dev/null 2>&1 || true
      ok "chrome"
      ;;
    slack)
      if ! snap list slack >/dev/null 2>&1; then
        step "Slack (snap)"; sudo snap install slack >/dev/null 2>&1 || warn "slack snap failed"
      fi
      ok "slack"
      ;;
    vlc)     apt_install vlc; ok "vlc" ;;
    deluge)  apt_install deluge-gtk deluged deluge-web; ok "deluge" ;;
    tilda)   apt_install tilda; ok "tilda" ;;
    gpaste)
      # GNOME-native clipboard manager (Wayland-friendly). Enabled in phase 80.
      apt_install gnome-shell-extension-gpaste
      ok "gpaste (enable in phase 80)"
      ;;
    copyq)
      apt_install copyq
      mkdir -p "$HOME/.config/autostart"
      [ -f /usr/share/applications/com.github.hluk.copyq.desktop ] && cp /usr/share/applications/com.github.hluk.copyq.desktop "$HOME/.config/autostart/" 2>/dev/null || true
      ok "copyq"
      ;;
    feh)     apt_install feh; ok "feh" ;;
    terminator) apt_install terminator; ok "terminator" ;;
    blueman) apt_install blueman; ok "blueman" ;;
    *) warn "no installer for app '$1'" ;;
  esac
}

for app in "${OHMAGUB_DESKTOP_APPS[@]}"; do install_app "$app"; done

# --- fonts (setup.sh install_fonts) ----------------------------------------
step "fonts"
apt_install fonts-firacode fonts-noto-color-emoji fonts-noto-mono fonts-font-awesome fontconfig
if ! fc-list | grep -qi "FiraCode Nerd Font"; then
  step "FiraCode Nerd Font"
  tmp="$(mktemp -d)"
  if fetch "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" "$tmp/FiraCode.zip"; then
    unzip -oq "$tmp/FiraCode.zip" -d "$tmp/FiraCode"
    mkdir -p "$HOME/.fonts"
    find "$tmp/FiraCode" -type f -iname 'Fira*.ttf' ! -iname '*windows*' -exec cp {} "$HOME/.fonts/" \;
    fc-cache -f >/dev/null 2>&1
    ok "FiraCode Nerd Font installed"
  else
    warn "FiraCode Nerd Font download failed"
  fi
  rm -rf "$tmp"
else
  ok "FiraCode Nerd Font present"
fi

ok "Phase apps complete"
