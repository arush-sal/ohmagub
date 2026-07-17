#!/usr/bin/env bash
#
# ohmagub phase: dev — Docker, Kubernetes stack, GitHub CLI, gcloud, AI CLIs.
# k8s install preference: bin > apt > direct binary.

set -euo pipefail
OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

log "Phase: dev"
ensure_sudo
export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Docker (official convenience script) + group + enable
# ---------------------------------------------------------------------------
if [ "${OHMAGUB_INSTALL_DOCKER:-1}" = "1" ]; then
  if ! has docker; then
    step "installing Docker (get.docker.com)"
    curl -fsSL https://get.docker.com | sudo sh
  else
    ok "docker present"
  fi
  # Add the invoking user to the docker group (idempotent; -aG is a no-op if
  # already a member). Takes effect on next login.
  sudo groupadd -f docker
  sudo usermod -aG docker "$(whoami)"
  warn "added $(whoami) to the docker group — log out/in to use docker without sudo"
  sudo systemctl enable --now docker >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# Kubernetes stack (bin > apt > direct)
# ---------------------------------------------------------------------------
bin_try() {
  has bin || return 1
  # Interactive picker when opted in AND stdin is a real terminal; otherwise
  # auto-select quietly (works unattended / under curl|bash where there's no TTY).
  if [ "${OHMAGUB_BIN_INTERACTIVE:-0}" = "1" ] && [ -t 0 ]; then
    echo "  (bin: pick the asset for $1)"
    bin install "$1"
  else
    bin install "$1" >/dev/null 2>&1
  fi
}
want() { case " ${OHMAGUB_K8S_TOOLS[*]} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# kubectl — apt (pkgs.k8s.io), minor auto-detected from the stable channel.
if want kubectl && ! has kubectl; then
  minor="v$(curl -fsSL https://dl.k8s.io/release/stable.txt | sed 's/^v//' | cut -d. -f1-2)"
  step "adding kubernetes apt repo ($minor)"
  sudo mkdir -p /etc/apt/keyrings
  fetch "https://pkgs.k8s.io/core:/stable:/${minor}/deb/Release.key" /tmp/k8s.key
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg < /tmp/k8s.key && rm -f /tmp/k8s.key
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${minor}/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
  apt_dirty; apt_install kubectl
  ok "kubectl installed ($minor)"
fi

# helm — bin, fallback to get-helm-3.
if want helm && ! has helm; then
  bin_try github.com/helm/helm || curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null 2>&1 || warn "helm install failed"
  has helm && ok "helm installed"
fi

# kubectx — bin, then the raw script (no API).
if want kubectx && ! has kubectx; then
  bin_try github.com/ahmetb/kubectx \
    || install_bin https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx kubectx \
    || true
  has kubectx && ok "kubectx installed" || warn "kubectx install failed"
fi

# kubens — direct raw script (bin installs only one binary from the kubectx repo).
if want kubens && ! has kubens; then
  install_bin https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens kubens && ok "kubens installed"
fi

# k9s — bin, then the official .deb (bin can't pick among k9s's apk/deb/rpm/
# tar.gz assets; the .deb name has no version so latest/download needs no API).
if want k9s && ! has k9s; then
  bin_try github.com/derailed/k9s \
    || install_deb "https://github.com/derailed/k9s/releases/latest/download/k9s_linux_$(gh_arch).deb" \
    || true
  has k9s && ok "k9s installed" || warn "k9s install failed (bin + .deb)"
fi

# kind — bin, then the direct binary (latest/download, no API — dodges rate limits).
if want kind && ! has kind; then
  bin_try github.com/kubernetes-sigs/kind \
    || install_bin "https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-linux-$(gh_arch)" kind \
    || true
  has kind && ok "kind installed" || warn "kind install failed (bin + direct)"
fi

# ---------------------------------------------------------------------------
# GitHub CLI + extensions
# ---------------------------------------------------------------------------
if ! has gh; then
  step "adding GitHub CLI apt repo"
  sudo mkdir -p /etc/apt/keyrings
  fetch https://cli.github.com/packages/githubcli-archive-keyring.gpg /tmp/gh.gpg
  sudo install -m 0644 /tmp/gh.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg && rm -f /tmp/gh.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  apt_dirty; apt_install gh
fi
for ext in "${OHMAGUB_GH_EXTENSIONS[@]}"; do
  step "gh extension: $ext"
  GIT_CONFIG_GLOBAL=/dev/null gh extension install "$ext" >/dev/null 2>&1 || warn "  $ext skipped (needs 'gh auth login' or already installed)"
done

# ---------------------------------------------------------------------------
# Google Cloud SDK (gated)
# ---------------------------------------------------------------------------
if [ "${OHMAGUB_INSTALL_GCLOUD:-1}" = "1" ] && ! has gcloud; then
  step "adding google-cloud-sdk apt repo"
  sudo mkdir -p /etc/apt/keyrings
  fetch https://packages.cloud.google.com/apt/doc/apt-key.gpg /tmp/gcloud.gpg
  sudo gpg --dearmor -o /etc/apt/keyrings/cloud.google.gpg < /tmp/gcloud.gpg 2>/dev/null || sudo cp /tmp/gcloud.gpg /etc/apt/keyrings/cloud.google.gpg
  rm -f /tmp/gcloud.gpg
  echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
  apt_dirty; apt_install google-cloud-cli && ok "gcloud installed"
fi

# ---------------------------------------------------------------------------
# AI coding CLIs (npm global — needs Node from phase 40)
# ---------------------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
if has npm; then
  if [ "${OHMAGUB_INSTALL_CODEX:-1}" = "1" ] && ! has codex; then
    step "npm i -g @openai/codex"; npm install -g @openai/codex >/dev/null 2>&1 && ok "Codex CLI installed" || warn "Codex CLI install failed"
  fi
  if [ "${OHMAGUB_INSTALL_CLAUDE_CODE:-1}" = "1" ] && ! has claude; then
    step "npm i -g @anthropic-ai/claude-code"; npm install -g @anthropic-ai/claude-code >/dev/null 2>&1 && ok "Claude Code installed" || warn "Claude Code install failed"
  fi
else
  warn "npm not found (run phase 40 first) — skipping AI CLIs"
fi

ok "Phase dev complete"
