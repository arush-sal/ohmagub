#!/usr/bin/env bash
#
# ohmagub phase: dotfiles-watch (OPTIONAL) — install a systemd *user* service
# that watches your dotfiles repo and auto-commits+pushes after edits settle.
# An inotify-based replacement for the old thrice-weekly force-push cron.
# Run explicitly:  ohmagub phase dotfiles-watch

set -euo pipefail
OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Phase: dotfiles-watch"
ensure_sudo
apt_install inotify-tools

# Expose the helper scripts on PATH.
mkdir -p "$HOME/.local/bin"
chmod +x "$OHMAGUB_PATH/bin/ohmagub-dotfiles-push" "$OHMAGUB_PATH/bin/ohmagub-dotfiles-watch"
ln -sf "$OHMAGUB_PATH/bin/ohmagub-dotfiles-push"  "$HOME/.local/bin/ohmagub-dotfiles-push"
ln -sf "$OHMAGUB_PATH/bin/ohmagub-dotfiles-watch" "$HOME/.local/bin/ohmagub-dotfiles-watch"

# systemd user unit.
unit_dir="$HOME/.config/systemd/user"
mkdir -p "$unit_dir"
cat > "$unit_dir/ohmagub-dotfiles-watch.service" <<EOF
[Unit]
Description=ohmagub: watch dotfiles and auto-commit+push on change
After=default.target

[Service]
Type=simple
Environment=OHMAGUB_DOTFILES_PATH=${OHMAGUB_DOTFILES_PATH}
Environment=OHMAGUB_WATCH_DEBOUNCE=${OHMAGUB_WATCH_DEBOUNCE:-10}
ExecStart=%h/.local/bin/ohmagub-dotfiles-watch
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

if systemctl --user daemon-reload 2>/dev/null; then
  systemctl --user enable --now ohmagub-dotfiles-watch.service 2>/dev/null \
    && ok "watcher enabled (systemctl --user status ohmagub-dotfiles-watch)" \
    || warn "couldn't enable user service now — enable after login: systemctl --user enable --now ohmagub-dotfiles-watch"
  # Survive logout (optional): uncomment to keep watching without an active session.
  # sudo loginctl enable-linger "$USER"
else
  warn "no user systemd session here — from your desktop run: systemctl --user enable --now ohmagub-dotfiles-watch"
fi

ok "Phase dotfiles-watch complete"
