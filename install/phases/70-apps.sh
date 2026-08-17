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
      if snap list slack >/dev/null 2>&1; then
        ok "slack present"
      elif has snap; then
        step "Slack (snap)"
        # Fresh VMs: snapd may still be seeding — installs fail until it's ready.
        sudo snap wait system seed.loaded 2>/dev/null || true
        if sudo snap install slack; then           # NOT silenced: show real errors
          ok "slack installed"
        else
          warn "slack snap failed (see error above) — retry later with: sudo snap install slack"
        fi
      else
        warn "snapd not available — skipping slack"
      fi
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
    localsend)
      # asset naming: LocalSend-<ver>-linux-x86-64.deb / -linux-arm-64.deb
      if ! is_installed localsend; then
        case "$(uname -m)" in
          x86_64)  install_release_deb localsend/localsend 'linux-x86-64\.deb$' LocalSend ;;
          aarch64) install_release_deb localsend/localsend 'linux-arm-64\.deb$' LocalSend ;;
          *)       warn "localsend: unsupported arch $(uname -m)" ;;
        esac
      else ok "localsend present"; fi
      ;;
    gnome-tweaks) apt_install gnome-tweaks; ok "gnome-tweaks" ;;
    tailscale)
      # Official script: adds the apt repo for this release, installs, enables
      # the daemon. Not logged in until you run `sudo tailscale up`.
      if ! has tailscale; then
        step "Tailscale"
        if curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1; then
          ok "tailscale installed — run 'sudo tailscale up' to join your tailnet"
        else
          warn "tailscale install failed (no repo for this release yet?) — see https://tailscale.com/download/linux"
        fi
      else
        ok "tailscale present"
      fi
      ;;
    obsidian)
      # asset naming: obsidian_<ver>_amd64.deb (no arm64 .deb published)
      if ! is_installed obsidian; then
        install_release_deb obsidianmd/obsidian-releases "_$(gh_arch)\.deb$" Obsidian
      else ok "obsidian present"; fi
      ;;
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
