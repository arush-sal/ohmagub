#!/usr/bin/env bash
#
# ohmagub phase: languages — Go (longsleep PPA), Node (nvm), Python (system).
# No mise, no pyenv (your dotfiles must be cleaned accordingly — see README).

set -euo pipefail
OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Phase: languages"
ensure_sudo

# --- Go (longsleep/golang-backports PPA) -----------------------------------
if ! has go; then
  step "adding ppa:longsleep/golang-backports"
  sudo add-apt-repository -y ppa:longsleep/golang-backports >/dev/null 2>&1 || warn "add-apt-repository (golang) failed"
  apt_dirty
  apt_install golang-go golang-doc golang-golang-x-tools
  ok "Go installed ($(go version 2>/dev/null || echo present))"
else
  ok "Go present ($(go version 2>/dev/null))"
fi
mkdir -p "$HOME/go/bin"

# --- Node (nvm) -------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  step "installing nvm"
  nvm_tag="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r .tag_name 2>/dev/null)"
  [ -n "$nvm_tag" ] && [ "$nvm_tag" != "null" ] || nvm_tag="v0.40.1"
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_tag}/install.sh" | bash
fi
# Load nvm into this shell and install the requested Node.
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  step "nvm install ${OHMAGUB_NODE_VERSION}"
  nvm install "${OHMAGUB_NODE_VERSION}" >/dev/null 2>&1 || warn "nvm install ${OHMAGUB_NODE_VERSION} failed"
  nvm alias default "${OHMAGUB_NODE_VERSION}" >/dev/null 2>&1 || true
  ok "Node ready ($(node --version 2>/dev/null || echo '?')), npm $(npm --version 2>/dev/null || echo '?')"
else
  warn "nvm not available — skipping Node"
fi

# --- Python (system) --------------------------------------------------------
apt_install python3 python3-pip python3-venv python-is-python3
ok "Python ready ($(python3 --version 2>/dev/null))"

ok "Phase languages complete"
