#!/usr/bin/env bash

# omagub :: bootstrap entry point
# Usage:  wget -qO- https://raw.githubusercontent.com/<you>/omagub/main/boot.sh | bash
#   or:   curl -fsSL https://raw.githubusercontent.com/<you>/omagub/main/boot.sh | bash
#
# This is the only thing you curl. It clones the repo and hands off to install.sh.

set -e

# ---------------------------------------------------------------------------
# Where omagub lives, and which repo/branch to pull.
# Override before running, e.g.:  OMAGUB_REF=dev bash boot.sh
# ---------------------------------------------------------------------------
OMAGUB_REPO="${OMAGUB_REPO:-arush-sal/omagub}"
OMAGUB_REF="${OMAGUB_REF:-main}"
OMAGUB_PATH="${OMAGUB_PATH:-$HOME/.local/share/omagub}"

ascii() {
  cat <<'EOF'

   ___  _ __ ___   __ _  __ _ _   _| |__
  / _ \| '_ ` _ \ / _` |/ _` | | | | '_ \
 | (_) | | | | | | (_| | (_| | |_| | |_) |
  \___/|_| |_| |_|\__,_|\__, |\__,_|_.__/
                        |___/

  A personal, tiling-friendly Ubuntu setup.  Feel the joy building.
EOF
}

ascii

echo "==> Making sure git is present..."
if ! command -v git >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y git
fi

echo "==> Cloning omagub into $OMAGUB_PATH (ref: $OMAGUB_REF)"
if [ -d "$OMAGUB_PATH" ]; then
  echo "    Existing checkout found. Updating."
  git -C "$OMAGUB_PATH" fetch --quiet origin "$OMAGUB_REF"
  git -C "$OMAGUB_PATH" checkout --quiet "$OMAGUB_REF"
  git -C "$OMAGUB_PATH" reset --hard --quiet "origin/$OMAGUB_REF"
else
  rm -rf "$OMAGUB_PATH"
  git clone --quiet "https://github.com/${OMAGUB_REPO}.git" "$OMAGUB_PATH"
  git -C "$OMAGUB_PATH" checkout --quiet "$OMAGUB_REF"
fi

echo "==> Handing off to the installer"
cd "$OMAGUB_PATH"
exec bash "$OMAGUB_PATH/install.sh"
