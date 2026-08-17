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
# Capture instead of piping into `grep -q`: grep exits at the first match, the
# resulting SIGPIPE makes fc-list exit 141, and under `set -o pipefail` that
# turns the whole check into a false "missing" every single run.
have_nerd_font() { case " $(fc-list 2>/dev/null || true) " in *"FiraCode Nerd Font"*) return 0 ;; *) return 1 ;; esac; }

if have_nerd_font; then
  ok "FiraCode Nerd Font present"
else
  step "FiraCode Nerd Font"
  # XDG font dir; ~/.fonts still works but fontconfig 2.15 treats it as legacy.
  fontdir="$HOME/.local/share/fonts"
  tmp="$(mktemp -d)"
  if ! fetch "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" "$tmp/FiraCode.zip"; then
    warn "FiraCode Nerd Font: download failed (offline? GitHub unreachable?)"
  elif ! has unzip; then
    warn "FiraCode Nerd Font: unzip missing — run phase 00 first"
  elif ! unzip_out="$(unzip -o "$tmp/FiraCode.zip" -d "$tmp/FiraCode" 2>&1)"; then
    warn "FiraCode Nerd Font: unzip failed — ${unzip_out##*$'\n'}"
  else
    mkdir -p "$fontdir"
    # v3 asset names are FiraCodeNerdFont*-*.ttf; older ones were FiraCode*.ttf.
    mapfile -d '' faces < <(find "$tmp/FiraCode" -type f -iname 'Fira*.tt[fc]' ! -iname '*windows*' -print0)
    [ "${#faces[@]}" -gt 0 ] && cp -f "${faces[@]}" "$fontdir/"
    # fc-cache exits non-zero for trouble in ANY font dir (unparseable file,
    # stale cache) — nothing to do with this font. Never let that kill the
    # phase, and never silence it either: >/dev/null 2>&1 with no guard is how
    # this block used to die with no output at all.
    if ! fc_out="$(fc-cache -f 2>&1)"; then
      warn "fc-cache reported a problem (fonts may still be fine): ${fc_out##*$'\n'}"
    fi
    if [ "${#faces[@]}" -eq 0 ]; then
      warn "FiraCode Nerd Font: no Fira*.ttf inside the zip — asset layout changed upstream"
    elif have_nerd_font; then
      ok "FiraCode Nerd Font installed (${#faces[@]} faces -> $fontdir)"
    else
      warn "FiraCode Nerd Font: copied ${#faces[@]} faces to $fontdir but fontconfig can't see them yet"
    fi
  fi
  rm -rf "$tmp"
fi

ok "Phase apps complete"
