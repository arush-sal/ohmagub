#!/usr/bin/env bash

# ohmagub :: bootstrap entry point
# Usage:  wget -qO- https://raw.githubusercontent.com/arush-sal/ohmagub/master/boot.sh | bash
#   or:   curl -fsSL https://raw.githubusercontent.com/arush-sal/ohmagub/master/boot.sh | bash
#
# This is the only thing you curl. It clones the repo and hands off to install.sh.

set -e

# ---------------------------------------------------------------------------
# Where ohmagub lives, and which repo/branch to pull.
# Override before running, e.g.:  OHMAGUB_REF=dev bash boot.sh
# ---------------------------------------------------------------------------
OHMAGUB_REPO="${OHMAGUB_REPO:-arush-sal/ohmagub}"
OHMAGUB_REF="${OHMAGUB_REF:-master}"
OHMAGUB_PATH="${OHMAGUB_PATH:-$HOME/.local/share/ohmagub}"

ascii() {
  cat <<'EOF'

  ════════════════════════════════════════════════════
     O H M A G U B
  ════════════════════════════════════════════════════
  a personal, tiling-friendly Ubuntu setup.  Feel the joy building.
EOF
}

ascii

echo "==> Making sure git is present..."
if ! command -v git >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y git
fi

echo "==> Cloning ohmagub into $OHMAGUB_PATH (ref: $OHMAGUB_REF)"
if [ -d "$OHMAGUB_PATH" ]; then
  echo "    Existing checkout found. Updating."
  git -C "$OHMAGUB_PATH" fetch --quiet origin "$OHMAGUB_REF"
  git -C "$OHMAGUB_PATH" checkout --quiet "$OHMAGUB_REF"
  git -C "$OHMAGUB_PATH" reset --hard --quiet "origin/$OHMAGUB_REF"
else
  rm -rf "$OHMAGUB_PATH"
  git clone --quiet "https://github.com/${OHMAGUB_REPO}.git" "$OHMAGUB_PATH"
  git -C "$OHMAGUB_PATH" checkout --quiet "$OHMAGUB_REF"
fi

echo "==> Handing off to the installer"
cd "$OHMAGUB_PATH"
exec bash "$OHMAGUB_PATH/install.sh"
