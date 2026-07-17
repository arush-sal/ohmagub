#!/usr/bin/env bash
#
# ============================================================================
#  omagub :: config.sh  —  YOUR single customization surface
# ============================================================================
#  Flip flags, edit lists, comment things out. Every phase reads from here.
#  Machine-specific secrets/tweaks go in config.local.sh (git-ignored).
# ============================================================================

# --- source & target -------------------------------------------------------
export OMAGUB_DOTFILES_REPO="${OMAGUB_DOTFILES_REPO:-https://github.com/arush-sal/dotfiles.git}"
export OMAGUB_DOTFILES_PATH="${OMAGUB_DOTFILES_PATH:-$HOME/Documents/dotfiles}"
export OMAGUB_GITHUB_USER="${OMAGUB_GITHUB_USER:-arush-sal}"   # for keys phase (pubkey + gist base)
# Top-level dotfile entries NOT synced by phase 20 (e.g. leftover i3/X11 files).
# .tmux is excluded because phase 30 assembles it (gpakosz base + your overlay).
OMAGUB_DOTFILES_EXCLUDE=( .tmux )
# Optional `dotfiles-watch` phase: seconds of quiet before an auto-commit+push.
export OMAGUB_WATCH_DEBOUNCE="${OMAGUB_WATCH_DEBOUNCE:-10}"

# --- system (phase 00) ------------------------------------------------------
export OMAGUB_TIMEZONE="${OMAGUB_TIMEZONE:-Asia/Kolkata}"
export OMAGUB_SHELL="${OMAGUB_SHELL:-zsh}"

# Extra apt packages always wanted (carried from setup.sh, non-i3). Idempotent;
# overlaps with autoinstall.yaml are skipped automatically.
OMAGUB_EXTRA_APT=(
  ffmpeg lm-sensors xsel cifs-utils arandr pm-utils
  mailutils postfix landscape-common xserver-xorg-input-synaptics
)

# --- languages (phase 40) ---------------------------------------------------
export OMAGUB_NODE_VERSION="${OMAGUB_NODE_VERSION:-lts/*}"   # nvm version spec
# Go: installed from the longsleep/golang-backports PPA (GOPATH = ~/go).
# Python: system python3 + pip (no version manager).

# --- dev + AI CLIs (phase 50) ----------------------------------------------
export OMAGUB_INSTALL_DOCKER=1
export OMAGUB_INSTALL_GCLOUD=1
export OMAGUB_INSTALL_CODEX=1          # OpenAI Codex CLI (npm global)
export OMAGUB_INSTALL_CLAUDE_CODE=1    # Anthropic Claude Code CLI (npm global)

# Kubernetes tooling to install.
OMAGUB_K8S_TOOLS=( kubectl helm kubectx kubens k9s kind )

# GitHub CLI extensions (from setup.sh).
OMAGUB_GH_EXTENSIONS=(
  mislav/gh-branch
  ericwb/gh-alerts
  einride/gh-dependabot
  dlvhdr/gh-prs
  rnorth/gh-combine-prs
  kawarimidoll/gh-q
  tst32/gh-gitignore
)

# --- desktop apps (phase 70) ------------------------------------------------
OMAGUB_DESKTOP_APPS=( chrome slack vlc deluge tilda gpaste )

# --- GNOME / tiling / workspaces (phase 80) --------------------------------
export OMAGUB_INSTALL_DESKTOP=1
export OMAGUB_WORKSPACES="${OMAGUB_WORKSPACES:-9}"
export OMAGUB_TILING_GAPS="${OMAGUB_TILING_GAPS:-8}"   # Tactile gap size (px)

# GNOME Shell extensions to install + enable (omakub catalog).
OMAGUB_GNOME_EXTENSIONS=(
  "tactile@lundal.io"                          # keyboard grid tiling (Super+T)
  "space-bar@luchrioh"                         # i3-style workspace labels
  "just-perfection-desktop@just-perfection"    # UI tweaks
  "blur-my-shell@aunetx"                       # blur (cosmetic)
  "undecorate@sun.wxg@gmail.com"               # remove title bars
  "tophat@fflewddur.github.io"                 # system monitor in top bar
)

# Per-workspace auto-open app (Auto Move Windows).
# Key = workspace number (1-9), value = .desktop id.
declare -gA OMAGUB_WORKSPACE_APPS=(
  [1]="org.gnome.Terminal.desktop"
  [2]="google-chrome.desktop"
  [3]="slack_slack.desktop"
  [4]="code.desktop"
  [5]="org.gnome.Nautilus.desktop"
  [9]="deluge.desktop"
)

# --- local overrides --------------------------------------------------------
if [ -f "$OMAGUB_PATH/config.local.sh" ]; then
  source "$OMAGUB_PATH/config.local.sh"
fi
: # ensure this file sources with a zero exit status under 'set -e'
