#!/usr/bin/env bash
#
# ohmagub :: lib/helpers.sh — shared, idempotent helpers sourced by every phase.

# ---------------------------------------------------------------------------
# Pretty output
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  _c_reset="$(printf '\033[0m')"; _c_blue="$(printf '\033[1;34m')"
  _c_green="$(printf '\033[1;32m')"; _c_yellow="$(printf '\033[1;33m')"
  _c_red="$(printf '\033[1;31m')"; _c_dim="$(printf '\033[2m')"
else
  _c_reset="" _c_blue="" _c_green="" _c_yellow="" _c_red="" _c_dim=""
fi
log()  { echo "${_c_blue}==>${_c_reset} $*"; }
step() { echo "${_c_dim}  ->${_c_reset} $*"; }
ok()   { echo "${_c_green}  OK${_c_reset} $*"; }
warn() { echo "${_c_yellow}  ! ${_c_reset} $*" >&2; }
err()  { echo "${_c_red}  x ${_c_reset} $*" >&2; }
die()  { err "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------------
has()          { command -v "$1" >/dev/null 2>&1; }
is_installed() { dpkg -s "$1" >/dev/null 2>&1; }
is_desktop()   { [ "${OHMAGUB_INSTALL_DESKTOP:-1}" = "1" ] && has gnome-shell; }

# The invoking (non-root) user's home, even when a step uses sudo.
user_home()    { echo "$HOME"; }

# ---------------------------------------------------------------------------
# sudo — warm up once, keep alive in the background for the whole run.
# Children inherit OHMAGUB_SUDO_READY so they don't spawn duplicate keep-alives.
# ---------------------------------------------------------------------------
ensure_sudo() {
  [ "${OHMAGUB_SUDO_READY:-}" = "1" ] && return 0
  [ "$(id -u)" -eq 0 ] && die "Run ohmagub as your normal user, not root — it uses sudo where needed."
  if ! sudo -v; then die "ohmagub needs sudo to install packages."; fi
  # Refresh the timestamp until the top-level shell exits.
  ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) >/dev/null 2>&1 &
  export OHMAGUB_SUDO_READY=1
}

# ---------------------------------------------------------------------------
# apt — batched, quiet, non-interactive, install-only-what's-missing.
# ---------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
# sudo runs with env_reset, so an exported DEBIAN_FRONTEND does NOT reach
# apt-get — packages with debconf questions (postfix, mailutils, iperf3...)
# would open a dialog and hang a TTY-less run. Pass it through explicitly on
# every apt-get; use APT_SUDO in place of `sudo apt-get`.
APT_SUDO=(sudo DEBIAN_FRONTEND=noninteractive apt-get)
_apt_updated=0
apt_update_once() { [ "$_apt_updated" = "1" ] && return 0; step "apt update"; "${APT_SUDO[@]}" update -y -qq; _apt_updated=1; }
apt_dirty()       { _apt_updated=0; }
apt_install() {
  local missing=() want=() p
  for p in "$@"; do is_installed "$p" || missing+=("$p"); done
  [ ${#missing[@]} -eq 0 ] && return 0
  apt_update_once
  # Package sets differ across releases (24.04 vs 26.04): skip what this
  # release doesn't ship instead of aborting the whole phase under `set -e`.
  for p in "${missing[@]}"; do
    if apt-cache show "$p" >/dev/null 2>&1; then
      want+=("$p")
    else
      warn "apt: '$p' not available on this Ubuntu release — skipped"
    fi
  done
  [ ${#want[@]} -eq 0 ] && return 0
  step "apt install: ${want[*]}"
  "${APT_SUDO[@]}" install -y -qq "${want[@]}"
}
apt_remove() { local p; for p in "$@"; do is_installed "$p" && "${APT_SUDO[@]}" remove -y -qq "$p" || true; done; }

# Preseed debconf answers so a package installs without asking. Values are
# fed verbatim to debconf-set-selections (one "pkg key type value" per line).
debconf_preseed() { printf '%s\n' "$@" | sudo debconf-set-selections; }

# ---------------------------------------------------------------------------
# Downloads
# ---------------------------------------------------------------------------
fetch()       { curl -fsSL "$1" -o "$2"; }
install_deb() { local tmp; tmp="$(mktemp --suffix=.deb)"; step "downloading $(basename "$1")"; fetch "$1" "$tmp"; "${APT_SUDO[@]}" install -y -qq "$tmp"; rm -f "$tmp"; }
# Fetch a single binary to /usr/local/bin (root-owned, executable).
install_bin() { # install_bin <url> <name>
  step "installing $2"
  sudo curl -fsSL "$1" -o "/usr/local/bin/$2" && sudo chmod +x "/usr/local/bin/$2"
}

# GitHub arch string for release assets.
gh_arch() { case "$(uname -m)" in x86_64) echo amd64 ;; aarch64) echo arm64 ;; *) echo amd64 ;; esac; }

# Install the newest .deb from a GitHub repo whose asset name matches a regex.
install_release_deb() {
  # install_release_deb <owner/repo> <asset-regex> <human name>
  local repo="$1" pat="$2" name="$3" url
  # Scan recent releases, not just /latest: projects ship platform-only point
  # releases (LocalSend v1.18.1 was Android-only), and /latest would then match
  # nothing even though the previous release has the .deb. Newest first, drafts
  # and prereleases excluded.
  # '|| true' guards the head/SIGPIPE + no-match cases under set -o pipefail.
  url="$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=10" \
        | jq -r '.[] | select(.draft == false and .prerelease == false) | .assets[].browser_download_url' \
        | grep -E "$pat" | head -1 || true)"
  if [ -n "$url" ]; then
    install_deb "$url"
    ok "$name installed"
  else
    warn "$name: no release .deb matching /$pat/ (arch unsupported? rate-limited?)"
  fi
}

# Never block on a credential prompt during install — fail fast instead.
export GIT_TERMINAL_PROMPT=0
# Clone/fetch a PUBLIC repo hermetically: ignore the user's global git config so
# their `insteadOf` https->SSH rewrite can't force credentials. Use for every
# internal clone. GIT_NO_GLOBAL is the prefix for tools that shell out to git.
export GIT_NO_GLOBAL="GIT_CONFIG_GLOBAL=/dev/null"
git_public() { GIT_CONFIG_GLOBAL=/dev/null git "$@"; }

# ---------------------------------------------------------------------------
# GNOME helpers (no-op off-desktop)
# ---------------------------------------------------------------------------
gset() {
  # gset <schema> <key> <value> — skip quietly if the schema isn't installed
  # (e.g. an optional extension/app is absent), warn only on a real set failure.
  is_desktop || return 0
  [ -n "${_gschemas:-}" ] || _gschemas=" $(gsettings list-schemas 2>/dev/null | tr '\n' ' ') "
  case "$_gschemas" in
    *" $1 "*) gsettings set "$1" "$2" "$3" 2>/dev/null || warn "gsettings $1 $2 failed" ;;
    *) step "skip (schema not present): $1" ;;
  esac
}
dconf_load() { is_desktop || return 0; dconf load "$1" < "$2"; }

# Enable a GNOME Shell extension. `gnome-extensions enable` fails for an
# extension the running shell hasn't scanned yet (anything apt-installed during
# this same run), so fall back to writing the UUID into enabled-extensions —
# gnome-shell picks it up at the next login either way.
ext_enable() { # ext_enable <uuid>
  is_desktop || return 0
  if gnome-extensions enable "$1" >/dev/null 2>&1; then step "enabled $1"; return 0; fi
  local cur="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || echo '@as []')"
  case "$cur" in *"'$1'"*) step "already enabled: $1"; return 0 ;; esac
  cur="${cur#@as }"
  [ "$cur" = "[]" ] && cur="['$1']" || cur="${cur%]}, '$1']"
  gsettings set org.gnome.shell enabled-extensions "$cur" 2>/dev/null \
    && step "enabled $1 (via enabled-extensions)" \
    || warn "could not enable $1"
}

# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------
backup_once() { [ -e "$1" ] || return 0; [ -e "$1.ohmagub.bak" ] && return 0; cp -a "$1" "$1.ohmagub.bak"; step "backed up $1"; }
ensure_line() { local f="$1" l="$2"; touch "$f"; grep -qxF "$l" "$f" || echo "$l" >> "$f"; }
ensure_block() {
  local file="$1" marker="$2"
  local begin="# >>> ohmagub:${marker} >>>" end="# <<< ohmagub:${marker} <<<"
  touch "$file"
  if grep -qF "$begin" "$file"; then
    sed -i "/$(printf '%s' "$begin" | sed 's/[][\/.*^$]/\\&/g')/,/$(printf '%s' "$end" | sed 's/[][\/.*^$]/\\&/g')/d" "$file"
  fi
  { echo "$begin"; cat; echo "$end"; } >> "$file"
}

export OHMAGUB_PATH="${OHMAGUB_PATH:-$HOME/.local/share/ohmagub}"
