#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase2_operator.sh
# Purpose : Phase 2 Operator Single Entry Point
# Run     : ./phase2_operator.sh
# ============================================================

PHASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${PHASE_DIR}/lib"
MAIN="${PHASE_DIR}/phase2_privilege_main.sh"

# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_runtime.sh" || { echo "ERROR: Missing phase2_lib_runtime.sh"; exit 3; }
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_utils.sh" || { echo "ERROR: Missing phase2_lib_utils.sh"; exit 3; }
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_menu.sh" || { echo "ERROR: Missing phase2_lib_menu.sh"; exit 3; }

if [[ ! -x "$MAIN" ]]; then
  echo "ERROR: Missing Phase 2 main script: $MAIN" >&2
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
    PHASE2_OUT_DIR="${intel}/Phase02_Privilege_Exp/team_$(printf "%03d" "$team")"
  else
    PHASE2_OUT_DIR="${base}/${intel}/Phase02_Privilege_Exp/team_$(printf "%03d" "$team")"
  fi
  export PHASE2_OUT_DIR
}

pick_scope() {
  phase2_menu__header "Phase 2 Operator" "Single Entry Point"
  phase2_menu__divider
  phase2_menu__print_kv "Note" "Team 19 is blocked"
  echo ""
  phase2_menu__choose "Select target scope" 1 \
    "Current team (if saved)" \
    "Enter a team number" \
    "All teams (1-20, Team19 blocked)" \
    "Exit"
}

run_for_team() {
  local team="$1"
  phase2_save_last_team "$team" || true
  set_intel_out_dir "$team"
  "$MAIN"
}

main() {
  phase2_init_run "phase2_operator" || true
  local choice
  choice="$(pick_scope)" || exit 0
  case "$choice" in
    1)
      local last
      last="$(phase2_load_last_team 2>/dev/null || true)"
      [[ -n "$last" ]] || { phase2_warn "No saved team; choose Enter a team number."; exit 1; }
      run_for_team "$last"
      ;;
    2)
      local t
      t="$(phase2_menu__ask "Enter team number")"
      phase2_validate_team "$t" || exit 1
      run_for_team "$t"
      ;;
    3)
      local t
      for t in $(seq 1 20); do
        if phase2_is_blocked_team "$t"; then
          continue
        fi
        phase2_save_last_team "$t" || true
        "$MAIN"
      done
      ;;
    0|4)
      exit 0
      ;;
  esac
}

main "$@"
