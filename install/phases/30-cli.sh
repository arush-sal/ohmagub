#!/usr/bin/env bash
#
# ohmagub phase: cli — command-line tooling that isn't a language or a dev/k8s
# tool. bin (binary manager) + tmux (gpakosz base + your overlay) + ripgrep.

set -euo pipefail
OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Phase: cli"
ensure_sudo
apt_install ripgrep jq

REPO="$OHMAGUB_DOTFILES_PATH"

# --- bin (marcosnils/bin) — installs single-file binaries from GitHub -------
if ! has bin; then
  case "$(uname -m)" in
    x86_64)  pat="Linux_x86_64" ;;
    aarch64) pat="Linux_arm64" ;;
    *)       pat="Linux_x86_64" ;;
  esac
  # '|| true': head closes the pipe early -> SIGPIPE upstream -> with pipefail
  # the pipeline reports failure even on success, which would abort the phase.
  url="$(curl -fsSL https://api.github.com/repos/marcosnils/bin/releases/latest \
        | jq -r '.assets[].browser_download_url' | grep "$pat" | head -1 || true)"
  if [ -n "$url" ]; then
    install_bin "$url" bin
    ok "bin installed"
  else
    warn "couldn't resolve a bin release asset for $pat"
  fi
else
  ok "bin present"
fi

# bin config: install binaries into ~/go/bin (setup.sh:164-176)
mkdir -p "$HOME/.bin" "$HOME/go/bin"
if [ ! -f "$HOME/.bin/config.json" ]; then
  cat > "$HOME/.bin/config.json" <<EOF
{
    "default_path": "$HOME/go/bin",
    "bins": {}
}
EOF
  ok "bin config -> ~/.bin/config.json (default_path ~/go/bin)"
fi

# --- tmux: gpakosz/.tmux (oh-my-tmux) base + your arush overlay -------------
apt_install tmux
if [ ! -d "$HOME/.tmux/.git" ]; then
  step "installing gpakosz/.tmux"
  rm -rf "$HOME/.tmux"
  git_public clone --depth=1 https://github.com/gpakosz/.tmux.git "$HOME/.tmux" >/dev/null 2>&1
fi
ln -sf "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
[ -e "$HOME/.tmux.conf.local" ] || ln -sf "$HOME/.tmux/.tmux.conf.local" "$HOME/.tmux.conf.local"
ensure_line "$HOME/.tmux.conf.local" "if '[ -f ~/.tmux/arush.tmux ]' 'source ~/.tmux/arush.tmux'"

# overlay your tmux modules from the dotfiles repo
if [ -d "$REPO/.tmux" ]; then
  for t in "$REPO"/.tmux/*.tmux; do
    [ -f "$t" ] && cp "$t" "$HOME/.tmux/$(basename "$t")"
  done
  ok "tmux overlay (arush.tmux/kube.tmux/minikube.tmux) applied"
fi

# --- yt-dlp (maintained replacement for setup.sh's youtube-dl) --------------
if ! has yt-dlp; then
  if apt-cache show yt-dlp >/dev/null 2>&1; then
    apt_install yt-dlp
  else
    # universal binary (needs python3, which Ubuntu desktop ships)
    install_bin "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" yt-dlp
  fi
  ok "yt-dlp installed"
else
  ok "yt-dlp present"
fi

ok "Phase cli complete"
