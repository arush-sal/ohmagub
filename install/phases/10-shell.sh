#!/usr/bin/env bash
#
# omagub phase: shell — zsh framework only. Your actual .zshrc, aliases, theme,
# and oh-my-zsh custom/ come from your dotfiles (phase 20), which is laid on top.

set -euo pipefail
OMAGUB_PATH="${OMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OMAGUB_PATH/lib/helpers.sh"
source "$OMAGUB_PATH/config.sh"

log "Phase: shell"
ensure_sudo

[ "${OMAGUB_SHELL:-zsh}" = "zsh" ] || { warn "OMAGUB_SHELL != zsh — nothing to do"; exit 0; }

apt_install zsh

# --- oh-my-zsh (unattended; don't clobber a .zshrc if one is already here) ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  step "installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  ok "oh-my-zsh present"
fi

# --- zsh-autosuggestions (your plugins list needs it) -----------------------
ZCUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ ! -d "$ZCUSTOM/plugins/zsh-autosuggestions" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZCUSTOM/plugins/zsh-autosuggestions" >/dev/null 2>&1
  ok "zsh-autosuggestions installed"
else
  ok "zsh-autosuggestions present"
fi

# --- fzf via junegunn (generates ~/.fzf.zsh that your env.zsh sources) -------
if [ ! -d "$HOME/.fzf" ]; then
  step "installing fzf (junegunn)"
  git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf" >/dev/null 2>&1
  "$HOME/.fzf/install" --all --no-bash --no-fish >/dev/null 2>&1
  ok "fzf installed"
else
  "$HOME/.fzf/install" --all --no-bash --no-fish >/dev/null 2>&1 || true
  ok "fzf present"
fi

# --- make zsh the login shell -----------------------------------------------
zsh_bin="$(command -v zsh)"
if [ "${SHELL:-}" != "$zsh_bin" ]; then
  grep -qx "$zsh_bin" /etc/shells 2>/dev/null || echo "$zsh_bin" | sudo tee -a /etc/shells >/dev/null
  sudo chsh -s "$zsh_bin" "$USER" && ok "login shell -> zsh (effective next login)" || warn "chsh failed"
fi

ok "Phase shell complete"
