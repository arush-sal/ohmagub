#!/usr/bin/env bash
#
# ============================================================================
#  ohmagub :: config.sh  —  YOUR single customization surface
# ============================================================================
#  Flip flags, edit lists, comment things out. Every phase reads from here.
#  Machine-specific secrets/tweaks go in config.local.sh (git-ignored).
# ============================================================================

# --- source & target -------------------------------------------------------
export OHMAGUB_DOTFILES_REPO="${OHMAGUB_DOTFILES_REPO:-https://github.com/arush-sal/dotfiles.git}"
export OHMAGUB_DOTFILES_PATH="${OHMAGUB_DOTFILES_PATH:-$HOME/Documents/dotfiles}"
export OHMAGUB_GITHUB_USER="${OHMAGUB_GITHUB_USER:-arush-sal}"   # for keys phase (pubkey + gist base)
# Top-level dotfile entries NOT synced by phase 20 (e.g. leftover i3/X11 files).
# .tmux is excluded because phase 30 assembles it (gpakosz base + your overlay).
OHMAGUB_DOTFILES_EXCLUDE=( .tmux )
# Optional `dotfiles-watch` phase: seconds of quiet before an auto-commit+push.
export OHMAGUB_WATCH_DEBOUNCE="${OHMAGUB_WATCH_DEBOUNCE:-10}"

# --- system (phase 00) ------------------------------------------------------
export OHMAGUB_TIMEZONE="${OHMAGUB_TIMEZONE:-Asia/Kolkata}"
export OHMAGUB_SHELL="${OHMAGUB_SHELL:-zsh}"

# Extra apt packages always wanted (carried from setup.sh, non-i3). Idempotent;
# overlaps with autoinstall.yaml are skipped automatically.
OHMAGUB_EXTRA_APT=(
  ffmpeg lm-sensors xsel cifs-utils arandr pm-utils
  mailutils postfix landscape-common xserver-xorg-input-synaptics
)

# --- languages (phase 40) ---------------------------------------------------
export OHMAGUB_NODE_VERSION="${OHMAGUB_NODE_VERSION:-lts/*}"   # nvm version spec
# Go: installed from the longsleep/golang-backports PPA (GOPATH = ~/go).
# Python: system python3 + pip (no version manager).

# --- dev + AI CLIs (phase 50) ----------------------------------------------
export OHMAGUB_INSTALL_DOCKER=1
export OHMAGUB_INSTALL_GCLOUD=1
export OHMAGUB_INSTALL_CODEX=1          # OpenAI Codex CLI (npm global)
export OHMAGUB_INSTALL_CLAUDE_CODE=1    # Anthropic Claude Code CLI (npm global)

# Let `bin` prompt you to pick a release asset (only when a TTY is present).
# 1 = interactive picker; 0 = auto-select silently then fall back. Interactive
# still needs the GitHub API, so a direct-download fallback is kept regardless.
export OHMAGUB_BIN_INTERACTIVE="${OHMAGUB_BIN_INTERACTIVE:-0}"

# Kubernetes tooling to install.
OHMAGUB_K8S_TOOLS=( kubectl helm kubectx kubens k9s kind )

# GitHub CLI extensions (from setup.sh).
OHMAGUB_GH_EXTENSIONS=(
  mislav/gh-branch
  ericwb/gh-alerts
  einride/gh-dependabot
  dlvhdr/gh-prs
  rnorth/gh-combine-prs
  kawarimidoll/gh-q
  tst32/gh-gitignore
)

# --- desktop apps (phase 70) ------------------------------------------------
OHMAGUB_DESKTOP_APPS=( chrome slack vlc deluge tilda gpaste localsend obsidian gnome-tweaks tailscale )

# --- GNOME / tiling / workspaces (phase 80) --------------------------------
export OHMAGUB_INSTALL_DESKTOP=1
export OHMAGUB_DISABLE_DOCK="${OHMAGUB_DISABLE_DOCK:-1}"   # 1 = remove the Ubuntu sidebar/dock
export OHMAGUB_WORKSPACES="${OHMAGUB_WORKSPACES:-9}"
export OHMAGUB_TILING_GAPS="${OHMAGUB_TILING_GAPS:-8}"   # Tactile gap size (px)

# GNOME Shell extensions to install + enable (omakub catalog).
OHMAGUB_GNOME_EXTENSIONS=(
  "tactile@lundal.io"                          # keyboard grid tiling (Super+T)
  "space-bar@luchrioh"                         # i3-style workspace labels
  "just-perfection-desktop@just-perfection"    # UI tweaks
  "blur-my-shell@aunetx"                       # blur (cosmetic)
  "undecorate@sun.wxg@gmail.com"               # remove title bars
  "tophat@fflewddur.github.io"                 # system monitor in top bar
)

# Per-workspace auto-open app (Auto Move Windows).
# Key = workspace number (1-9), value = .desktop id.
declare -gA OHMAGUB_WORKSPACE_APPS=(
  [1]="org.gnome.Terminal.desktop"
  [2]="google-chrome.desktop"
  [3]="slack_slack.desktop"
  [4]="code.desktop"
  [5]="org.gnome.Nautilus.desktop"
  [9]="deluge.desktop"
)

# Dock / overview-dash favourites, pinned in this order (phase 80). Mirrors the
# workspace map above so the pin order matches the workspace order.
OHMAGUB_DOCK_FAVORITES=(
  "org.gnome.Terminal.desktop"
  "google-chrome.desktop"
  "slack_slack.desktop"
  "code.desktop"
  "org.gnome.Nautilus.desktop"
)

# Launched at login (phase 80) — .desktop ids copied into ~/.config/autostart.
# Each lands on its assigned workspace via Auto Move Windows.
OHMAGUB_AUTOSTART_APPS=(
  "org.gnome.Terminal.desktop"
  "google-chrome.desktop"
  "slack_slack.desktop"
)

# --- local overrides --------------------------------------------------------
if [ -f "$OHMAGUB_PATH/config.local.sh" ]; then
  source "$OHMAGUB_PATH/config.local.sh"
fi
: # ensure this file sources with a zero exit status under 'set -e'
