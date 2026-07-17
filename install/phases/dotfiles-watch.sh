#!/usr/bin/env bash
#
# omagub phase: dotfiles-watch (OPTIONAL) — install a systemd *user* service
# that watches your dotfiles repo and auto-commits+pushes after edits settle.
# An inotify-based replacement for the old thrice-weekly force-push cron.
# Run explicitly:  omagub phase dotfiles-watch

set -euo pipefail
OMAGUB_PATH="${OMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OMAGUB_PATH/lib/helpers.sh"
source "$OMAGUB_PATH/config.sh"

log "Phase: dotfiles-watch"
ensure_sudo
apt_install inotify-tools

# Expose the helper scripts on PATH.
mkdir -p "$HOME/.local/bin"
chmod +x "$OMAGUB_PATH/bin/omagub-dotfiles-push" "$OMAGUB_PATH/bin/omagub-dotfiles-watch"
ln -sf "$OMAGUB_PATH/bin/omagub-dotfiles-push"  "$HOME/.local/bin/omagub-dotfiles-push"
ln -sf "$OMAGUB_PATH/bin/omagub-dotfiles-watch" "$HOME/.local/bin/omagub-dotfiles-watch"

# systemd user unit.
unit_dir="$HOME/.config/systemd/user"
mkdir -p "$unit_dir"
cat > "$unit_dir/omagub-dotfiles-watch.service" <<EOF
[Unit]
Description=omagub: watch dotfiles and auto-commit+push on change
After=default.target

[Service]
Type=simple
Environment=OMAGUB_DOTFILES_PATH=${OMAGUB_DOTFILES_PATH}
Environment=OMAGUB_WATCH_DEBOUNCE=${OMAGUB_WATCH_DEBOUNCE:-10}
ExecStart=%h/.local/bin/omagub-dotfiles-watch
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

if systemctl --user daemon-reload 2>/dev/null; then
  systemctl --user enable --now omagub-dotfiles-watch.service 2>/dev/null \
    && ok "watcher enabled (systemctl --user status omagub-dotfiles-watch)" \
    || warn "couldn't enable user service now — enable after login: systemctl --user enable --now omagub-dotfiles-watch"
  # Survive logout (optional): uncomment to keep watching without an active session.
  # sudo loginctl enable-linger "$USER"
else
  warn "no user systemd session here — from your desktop run: systemctl --user enable --now omagub-dotfiles-watch"
fi

ok "Phase dotfiles-watch complete"
