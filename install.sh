#!/usr/bin/env bash
#
# ohmagub :: install.sh — the phase engine.
#   bash install.sh              run every phase in order (full setup)
#   bash install.sh <name|num>   run a single phase (e.g. "preflight" or "00")
#   bash install.sh list         list phases
#
# Phases live in install/phases/NN-name.sh (core, numbered) plus optional
# un-numbered phases (keys.sh, cron.sh) that only run when named explicitly.

set -euo pipefail
export OHMAGUB_PATH="${OHMAGUB_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$OHMAGUB_PATH/lib/helpers.sh"
source "$OHMAGUB_PATH/config.sh"

PHASES_DIR="$OHMAGUB_PATH/install/phases"

# All core (numbered) phase files, in order.
core_phases() { find "$PHASES_DIR" -maxdepth 1 -name '[0-9][0-9]-*.sh' 2>/dev/null | sort; }

# Resolve "preflight" or "00" or "00-preflight" to a phase file path.
resolve_phase() {
  local q="$1" f
  for f in "$PHASES_DIR"/*.sh; do
    [ -f "$f" ] || continue
    local base; base="$(basename "$f" .sh)"      # e.g. 00-preflight
    local num="${base%%-*}" name="${base#*-}"    # 00 , preflight
    if [ "$q" = "$base" ] || [ "$q" = "$name" ] || [ "$q" = "$num" ]; then
      echo "$f"; return 0
    fi
  done
  return 1
}

list_phases() {
  echo "Core phases (run in this order by 'ohmagub install'):"
  local f
  for f in $(core_phases); do
    local base; base="$(basename "$f" .sh)"
    printf "  %-4s %s\n" "${base%%-*}" "${base#*-}"
  done
  echo "Optional phases (run explicitly, e.g. 'ohmagub phase keys'):"
  for f in "$PHASES_DIR"/*.sh; do
    [ -f "$f" ] || continue
    local base; base="$(basename "$f" .sh)"
    case "$base" in [0-9][0-9]-*) ;; *) printf "  %-4s %s\n" "-" "$base" ;; esac
  done
}

run_phase_file() {
  local f="$1"
  [ -f "$f" ] || die "phase not found: $f"
  log "Running phase: $(basename "$f" .sh)"
  OHMAGUB_PATH="$OHMAGUB_PATH" bash "$f"
}

main() {
  local target="${1:-all}"
  case "$target" in
    all)
      ensure_sudo
      local f name rc failed=()
      for f in $(core_phases); do
        name="$(basename "$f" .sh)"
        rc=0
        run_phase_file "$f" || rc=$?
        if [ "$rc" -ne 0 ]; then
          echo
          err "PHASE FAILED: $name (exit $rc) — continuing with the remaining phases"
          err "  fix it, then re-run just this phase:  ohmagub phase $name"
          echo
          failed+=("$name")
        fi
      done
      echo
      if [ ${#failed[@]} -eq 0 ]; then
        ok "ohmagub: all phases complete."
      else
        err "ohmagub finished, but ${#failed[@]} phase(s) FAILED: ${failed[*]}"
        err "re-run each after fixing, e.g.:  ohmagub phase ${failed[0]}"
      fi
      echo "${_c_dim}   Log out and back in for shell, docker group, and GNOME extensions to take effect.${_c_reset}"
      [ ${#failed[@]} -eq 0 ] || exit 1
      ;;
    list|--list|-l) list_phases ;;
    *)
      local f; f="$(resolve_phase "$target")" || die "unknown phase '$target' (try: bash install.sh list)"
      ensure_sudo
      run_phase_file "$f"
      ;;
  esac
}
main "$@"
