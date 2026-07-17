#!/usr/bin/env bash
#
# omagub :: lib/helpers.sh — shared, idempotent helpers sourced by every phase.

# ---------------------------------------------------------------------------
# Pretty output
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  _c_reset="$(printf '\033[0m')"; _c_blue="$(printf '\033[1;34m')"
  _c_green="$(printf '\033[1;32m')"; _c_yellow="$(printf '\033[1;33m')"
  _c_red="$(printf '\033[1;31m')"; _c_dim="$(printf '\033[2m')"
else
  _c_reset="" _c_blue="" _c_green="" _c_yellow="" _c_red="" _c_dim=""
fi
log()  { echo "${_c_blue}==>${_c_reset} $*"; }
step() { echo "${_c_dim}  ->${_c_reset} $*"; }
ok()   { echo "${_c_green}  OK${_c_reset} $*"; }
warn() { echo "${_c_yellow}  ! ${_c_reset} $*" >&2; }
err()  { echo "${_c_red}  x ${_c_reset} $*" >&2; }
die()  { err "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------------
has()          { command -v "$1" >/dev/null 2>&1; }
is_installed() { dpkg -s "$1" >/dev/null 2>&1; }
is_desktop()   { [ "${OMAGUB_INSTALL_DESKTOP:-1}" = "1" ] && has gnome-shell; }

# The invoking (non-root) user's home, even when a step uses sudo.
user_home()    { echo "$HOME"; }

# ---------------------------------------------------------------------------
# sudo — warm up once, keep alive in the background for the whole run.
# Children inherit OMAGUB_SUDO_READY so they don't spawn duplicate keep-alives.
# ---------------------------------------------------------------------------
ensure_sudo() {
  [ "${OMAGUB_SUDO_READY:-}" = "1" ] && return 0
  [ "$(id -u)" -eq 0 ] && die "Run omagub as your normal user, not root — it uses sudo where needed."
  if ! sudo -v; then die "omagub needs sudo to install packages."; fi
  # Refresh the timestamp until the top-level shell exits.
  ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) >/dev/null 2>&1 &
  export OMAGUB_SUDO_READY=1
}

# ---------------------------------------------------------------------------
# apt — batched, quiet, non-interactive, install-only-what's-missing.
# ---------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
_apt_updated=0
apt_update_once() { [ "$_apt_updated" = "1" ] && return 0; step "apt update"; sudo apt-get update -y -qq; _apt_updated=1; }
apt_dirty()       { _apt_updated=0; }
apt_install() {
  local want=() p
  for p in "$@"; do is_installed "$p" || want+=("$p"); done
  [ ${#want[@]} -eq 0 ] && return 0
  apt_update_once
  step "apt install: ${want[*]}"
  sudo apt-get install -y -qq "${want[@]}"
}
apt_remove() { local p; for p in "$@"; do is_installed "$p" && sudo apt-get remove -y -qq "$p" || true; done; }

# ---------------------------------------------------------------------------
# Downloads
# ---------------------------------------------------------------------------
fetch()       { curl -fsSL "$1" -o "$2"; }
install_deb() { local tmp; tmp="$(mktemp --suffix=.deb)"; step "downloading $(basename "$1")"; fetch "$1" "$tmp"; sudo apt-get install -y -qq "$tmp"; rm -f "$tmp"; }
# Fetch a single binary to /usr/local/bin (root-owned, executable).
install_bin() { # install_bin <url> <name>
  step "installing $2"
  sudo curl -fsSL "$1" -o "/usr/local/bin/$2" && sudo chmod +x "/usr/local/bin/$2"
}

# GitHub arch string for release assets.
gh_arch() { case "$(uname -m)" in x86_64) echo amd64 ;; aarch64) echo arm64 ;; *) echo amd64 ;; esac; }

# ---------------------------------------------------------------------------
# GNOME helpers (no-op off-desktop)
# ---------------------------------------------------------------------------
gset()      { is_desktop || return 0; gsettings set "$1" "$2" "$3" 2>/dev/null || warn "gsettings $1 $2 failed"; }
dconf_load() { is_desktop || return 0; dconf load "$1" < "$2"; }

# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------
backup_once() { [ -e "$1" ] || return 0; [ -e "$1.omagub.bak" ] && return 0; cp -a "$1" "$1.omagub.bak"; step "backed up $1"; }
ensure_line() { local f="$1" l="$2"; touch "$f"; grep -qxF "$l" "$f" || echo "$l" >> "$f"; }
ensure_block() {
  local file="$1" marker="$2"
  local begin="# >>> omagub:${marker} >>>" end="# <<< omagub:${marker} <<<"
  touch "$file"
  if grep -qF "$begin" "$file"; then
    sed -i "/$(printf '%s' "$begin" | sed 's/[][\/.*^$]/\\&/g')/,/$(printf '%s' "$end" | sed 's/[][\/.*^$]/\\&/g')/d" "$file"
  fi
  { echo "$begin"; cat; echo "$end"; } >> "$file"
}

export OMAGUB_PATH="${OMAGUB_PATH:-$HOME/.local/share/omagub}"
