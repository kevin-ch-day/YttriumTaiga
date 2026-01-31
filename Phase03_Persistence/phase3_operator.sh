#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase3_operator.sh
# Purpose : Phase 3 Operator Single Entry Point
# Run     : ./phase3_operator.sh
# ============================================================

PHASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN="${PHASE_DIR}/phase3_continuity.sh"

# shellcheck disable=SC1091
source "${PHASE_DIR}/lib/ccdc_runtime.sh" || { echo "ERROR: Missing lib/ccdc_runtime.sh"; exit 3; }
# shellcheck disable=SC1091
source "${PHASE_DIR}/lib/ccdc_utils.sh" || { echo "ERROR: Missing lib/ccdc_utils.sh"; exit 3; }
# shellcheck disable=SC1091
source "${PHASE_DIR}/lib/ccdc_menu.sh" || { echo "ERROR: Missing lib/ccdc_menu.sh"; exit 3; }

if [[ ! -x "$MAIN" ]]; then
  echo "ERROR: Missing Phase 3 main script: $MAIN" >&2
  exit 2
fi

load_rules() {
  local rules="${PHASE_DIR}/../config/ccdc_rules.conf"
  if [[ -f "$rules" ]]; then
    # shellcheck disable=SC1090
    source "$rules" || true
  fi
}

set_intel_out_dir() {
  local team="$1"
  load_rules
  local base="${PHASE_DIR}/.."
  local intel="${CCDC_INTEL_DIR:-data/intel}"
  if [[ "$intel" = /* ]]; then
    export CCDC_OUT_DIR="${intel}/Phase03_Persistence/team_$(printf "%03d" "$team")"
  else
    export CCDC_OUT_DIR="${base}/${intel}/Phase03_Persistence/team_$(printf "%03d" "$team")"
  fi
  export CCDC_OUT_DIR_BASE="${CCDC_OUT_DIR}"
}

pick_scope() {
  ccdc_menu__header "Phase 3 Operator" "Single Entry Point"
  ccdc_menu__divider
  ccdc_menu__print_kv "Note" "Team 19 is blocked"
  echo ""
  ccdc_menu__choose "Select target scope" 1 \
    "Current team (if saved)" \
    "Enter a team number" \
    "All teams (1-20, Team19 blocked)" \
    "Exit"
}

run_for_team() {
  local team="$1"
  ccdc__save_last_team "$team" || true
  set_intel_out_dir "$team"
  "$MAIN"
}

main() {
  ccdc__init_run "phase3_operator" || true
  local choice
  choice="$(pick_scope)" || exit 0
  case "$choice" in
    1)
      local last
      last="$(ccdc__load_last_team 2>/dev/null || true)"
      [[ -n "$last" ]] || { ccdc__warn "No saved team; choose Enter a team number."; exit 1; }
      run_for_team "$last"
      ;;
    2)
      local t
      t="$(ccdc_menu__ask "Enter team number")"
      ccdc__validate_team "$t" || exit 1
      run_for_team "$t"
      ;;
    3)
      local t
      for t in $(seq 1 20); do
        if ccdc__is_blocked_team "$t"; then
          continue
        fi
        ccdc__save_last_team "$t" || true
        "$MAIN"
      done
      ;;
    0|4)
      exit 0
      ;;
  esac
}

main "$@"
