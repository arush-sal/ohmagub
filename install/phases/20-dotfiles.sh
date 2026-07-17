#!/usr/bin/env bash
#
# ohmagub phase: dotfiles — clone your dotfiles and lay them over $HOME.
# Home-mirror layout: repo-root .* entries -> $HOME, usr/local/bin/* -> /usr/local/bin.
# NOTE: clean your repo for native Ubuntu first (see README "dotfiles cleanup").

set -euo pipefail
OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Phase: dotfiles"
ensure_sudo
apt_install rsync git

REPO="$OHMAGUB_DOTFILES_PATH"

# --- clone via HTTPS (before the SSH rewrite), or update in place -----------
if [ ! -d "$REPO/.git" ]; then
  step "cloning dotfiles -> $REPO"
  mkdir -p "$(dirname "$REPO")"
  git clone "$OHMAGUB_DOTFILES_REPO" "$REPO"
else
  step "updating dotfiles ($REPO)"
  git -C "$REPO" pull --ff-only 2>/dev/null || warn "dotfiles pull skipped (local changes / non-ff)"
fi

# --- switch remote to SSH (matches setup.sh:270) ----------------------------
ssh_url="$(echo "$OHMAGUB_DOTFILES_REPO" | sed -E 's#^https?://github.com/#git@github.com:#')"
git -C "$REPO" remote set-url origin "$ssh_url" 2>/dev/null || true

# --- sync home-mirror dotfiles into $HOME -----------------------------------
shopt -s dotglob nullglob
synced=0
for entry in "$REPO"/.*; do
  base="$(basename "$entry")"
  case "$base" in .|..|.git|.gitignore|.gitattributes) continue ;; esac
  skip=0
  for ex in "${OHMAGUB_DOTFILES_EXCLUDE[@]}"; do [ "$base" = "$ex" ] && skip=1; done
  if [ "$skip" = "1" ]; then step "skip (excluded): $base"; continue; fi
  rsync -a "$entry" "$HOME/"
  synced=$((synced + 1))
done
shopt -u dotglob nullglob
ok "synced $synced dotfile entries into \$HOME"

# --- sync usr/local/bin scripts ---------------------------------------------
if [ -d "$REPO/usr/local/bin" ]; then
  for f in "$REPO"/usr/local/bin/*; do
    [ -f "$f" ] || continue
    sudo cp "$f" /usr/local/bin/ && sudo chmod +x "/usr/local/bin/$(basename "$f")"
  done
  ok "synced usr/local/bin scripts"
fi

# --- HTTPS -> SSH rewrite (after clone, per setup.sh:324) -------------------
git config --global url."git@github.com:".insteadOf "https://github.com/"

ok "Phase dotfiles complete"
