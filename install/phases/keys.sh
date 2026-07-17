#!/usr/bin/env bash
#
# ohmagub phase: keys (OPTIONAL, INTERACTIVE) — import your SSH + GPG keys from
# your private GitHub gists. Run explicitly:  ohmagub phase keys
#
# SECURITY: this prompts YOU for a gist token + gist ids at runtime and writes
# keys into ~/.ssh and your GPG keyring. Nothing is stored in the ohmagub repo.
# Not part of `ohmagub install`. No sudo needed.

set -euo pipefail
OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Phase: keys (interactive)"
warn "This imports PRIVATE keys from your GitHub gists. You'll be prompted for a"
warn "gist token and gist ids. Keys go into ~/.ssh and your GPG keyring only."
read -r -p "Continue? [y/N] " ans
case "$ans" in y|Y|yes) ;; *) echo "aborted."; exit 0 ;; esac

GH_USER="${OHMAGUB_GITHUB_USER:-arush-sal}"
GIST_URL="https://gist.githubusercontent.com/${GH_USER}"

read -rs -p "GitHub Gist token: " TOKEN; echo
[ -n "$TOKEN" ] || die "no token provided"

# --- SSH --------------------------------------------------------------------
read -r -p "SSH private-key gist id (blank to skip): " SSH_GIST
if [ -n "$SSH_GIST" ]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  if curl -fsSL -H "authToken: $TOKEN" "$GIST_URL/$SSH_GIST/raw" -o "$HOME/.ssh/id_rsa"; then
    chmod 600 "$HOME/.ssh/id_rsa"
    curl -fsSL "https://github.com/${GH_USER}.keys" -o "$HOME/.ssh/id_rsa.pub" && chmod 644 "$HOME/.ssh/id_rsa.pub"
    ok "SSH key installed (~/.ssh/id_rsa 0600, id_rsa.pub 0644)"
  else
    warn "SSH key fetch failed"
  fi
fi

# --- GPG keys (loop) --------------------------------------------------------
while true; do
  read -r -p "GPG key gist id to import (blank to stop): " GPG_GIST
  [ -n "$GPG_GIST" ] || break
  if curl -fsSL -H "authToken: $TOKEN" "$GIST_URL/$GPG_GIST/raw" | gpg --batch --import; then
    ok "GPG key imported"
  else
    warn "GPG import failed for $GPG_GIST"
  fi
done

# --- GPG ownertrust ---------------------------------------------------------
read -r -p "GPG ownertrust gist id (blank to skip): " TRUST_GIST
if [ -n "$TRUST_GIST" ]; then
  curl -fsSL -H "authToken: $TOKEN" "$GIST_URL/$TRUST_GIST/raw" | gpg --import-ownertrust && ok "ownertrust imported" || warn "ownertrust import failed"
fi

unset TOKEN
ok "Phase keys complete"
