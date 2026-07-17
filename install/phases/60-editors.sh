#!/usr/bin/env bash
#
# ohmagub phase: editors — vim (vim-gtk3 + Vundle) and VS Code (bare).
# Neovim intentionally skipped. Depends on: .vimrc (phase 20), Go (phase 40).

set -euo pipefail
OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Phase: editors"
ensure_sudo
export PATH="$HOME/go/bin:/usr/local/go/bin:$PATH"

# --- vim + Vundle (user) ----------------------------------------------------
apt_install vim-gtk3

if [ ! -d "$HOME/.vim/bundle/Vundle.vim" ]; then
  step "cloning Vundle"
  git_public clone --depth=1 https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim" >/dev/null 2>&1
fi
if [ -f "$HOME/.vimrc" ]; then
  # GIT_CONFIG_GLOBAL=/dev/null: Vundle git-clones each plugin from GitHub;
  # without this your .gitconfig insteadOf would force SSH (credentials).
  step "vim +PluginInstall"
  GIT_CONFIG_GLOBAL=/dev/null vim +PluginInstall +qall! </dev/null >/dev/null 2>&1 || warn "vim PluginInstall had issues"
  if has go; then
    step "vim +GoInstallBinaries"
    GIT_CONFIG_GLOBAL=/dev/null vim +GoInstallBinaries +qall! </dev/null >/dev/null 2>&1 || warn "GoInstallBinaries skipped (vim-go not present?)"
  fi
  ok "vim configured"
else
  warn "~/.vimrc missing — run phase 20 (dotfiles) first"
fi

# --- vim for root (faithful to setup.sh:318-319) ---------------------------
if [ -f "$HOME/.vimrc" ]; then
  sudo cp "$HOME/.vimrc" /root/.vimrc
  sudo test -d /root/.vim/bundle/Vundle.vim || sudo env GIT_CONFIG_GLOBAL=/dev/null git clone --depth=1 https://github.com/VundleVim/Vundle.vim.git /root/.vim/bundle/Vundle.vim >/dev/null 2>&1
  sudo env GIT_CONFIG_GLOBAL=/dev/null vim +PluginInstall +qall! </dev/null >/dev/null 2>&1 || warn "root vim PluginInstall had issues"
  ok "root vim configured"
fi

# --- VS Code (bare, official apt repo) -------------------------------------
if ! has code; then
  step "adding VS Code apt repo"
  fetch https://packages.microsoft.com/keys/microsoft.asc /tmp/ms.asc
  sudo gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg < /tmp/ms.asc && rm -f /tmp/ms.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  apt_dirty; apt_install code
  ok "VS Code installed"
else
  ok "VS Code present"
fi

ok "Phase editors complete"
