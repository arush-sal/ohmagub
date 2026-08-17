#!/usr/bin/env bash
#
# ohmagub phase: preflight — prepare the system. Installs no applications.
# Idempotent: safe to re-run.

set -euo pipefail
OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Phase: preflight"
ensure_sudo

# --- OS check (supported: Ubuntu 24.04+) -----------------------------------
if [ -r /etc/os-release ]; then
  . /etc/os-release
  if [ "${ID:-}" != "ubuntu" ]; then
    warn "ohmagub targets Ubuntu (found: ${ID:-unknown}). Continuing anyway."
  else
    ver_major="${VERSION_ID%%.*}"
    if [ "${ver_major:-0}" -ge 24 ] 2>/dev/null; then
      ok "Ubuntu ${VERSION_ID} detected"
    else
      warn "ohmagub supports Ubuntu 24.04+ — found ${VERSION_ID}. GNOME/extension bits may differ."
    fi
  fi
else
  warn "no /etc/os-release — cannot verify OS"
fi

# --- enable universe / multiverse / restricted -----------------------------
if has add-apt-repository; then
  step "enabling universe/multiverse/restricted"
  for comp in universe multiverse restricted; do
    sudo add-apt-repository -y "$comp" >/dev/null 2>&1 || true
  done
  apt_dirty
fi

# --- base packages (idempotent; most already present via autoinstall.yaml) --
apt_install \
  curl wget git unzip ca-certificates gnupg \
  apt-transport-https software-properties-common build-essential \
  net-tools inetutils-tools jq

[ "${#OHMAGUB_EXTRA_APT[@]}" -gt 0 ] && apt_install "${OHMAGUB_EXTRA_APT[@]}"

# --- yq (mikefarah) — apt's 'yq' is the wrong tool, so grab the binary ------
if ! has yq; then
  install_bin "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(gh_arch)" yq \
    && ok "yq installed" || warn "yq install failed"
else
  ok "yq present"
fi

# --- locale -----------------------------------------------------------------
step "locale -> en_US.UTF-8"
sudo locale-gen --purge en_US.UTF-8 >/dev/null 2>&1 || sudo locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
printf 'LANG="en_US.UTF-8"\nLANGUAGE="en_US:en"\n' | sudo tee /etc/default/locale >/dev/null

# --- timezone + time sync ---------------------------------------------------
if has timedatectl && [ -n "${OHMAGUB_TIMEZONE:-}" ]; then
  sudo timedatectl set-timezone "$OHMAGUB_TIMEZONE" 2>/dev/null && ok "timezone -> $OHMAGUB_TIMEZONE" || warn "timezone set failed"
fi
sudo systemctl enable --now systemd-timesyncd >/dev/null 2>&1 || true

# --- GRUB: fast boot, no splash cmdline (matches setup.sh + autoinstall) ----
if [ -f /etc/default/grub ]; then
  step "tuning GRUB"
  sudo cp -n /etc/default/grub /etc/default/grub.ohmagub.bak 2>/dev/null || true
  sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
  grep -q '^GRUB_RECORDFAIL_TIMEOUT' /etc/default/grub || echo 'GRUB_RECORDFAIL_TIMEOUT=5' | sudo tee -a /etc/default/grub >/dev/null
  sudo update-grub >/dev/null 2>&1 || sudo update-grub2 >/dev/null 2>&1 || warn "update-grub failed"
fi

# --- default terminal alternative (browser alt is set in phase 70) ----------
if [ -e /usr/bin/gnome-terminal.wrapper ]; then
  sudo update-alternatives --set x-terminal-emulator /usr/bin/gnome-terminal.wrapper >/dev/null 2>&1 || true
fi

# --- root gets a red prompt (from setup.sh:262-263) -------------------------
if [ -f "$HOME/.bashrc" ]; then
  sudo cp "$HOME/.bashrc" /root/.bashrc 2>/dev/null || true
  sudo sed -i 's/01;32m/01;31m/g' /root/.bashrc 2>/dev/null || true
  step "root prompt set to red"
fi

# --- expose the ohmagub CLI on PATH -----------------------------------------
chmod +x "$OHMAGUB_PATH/bin/ohmagub" "$OHMAGUB_PATH/boot.sh" "$OHMAGUB_PATH/install.sh" 2>/dev/null || true
# /usr/local/bin is on PATH by default, so `ohmagub` works immediately (no
# re-login needed). Also mirror into ~/.local/bin for good measure.
sudo ln -sf "$OHMAGUB_PATH/bin/ohmagub" /usr/local/bin/ohmagub
mkdir -p "$HOME/.local/bin"
ln -sf "$OHMAGUB_PATH/bin/ohmagub" "$HOME/.local/bin/ohmagub"
ok "ohmagub CLI linked -> /usr/local/bin/ohmagub"

ok "Phase preflight complete"
