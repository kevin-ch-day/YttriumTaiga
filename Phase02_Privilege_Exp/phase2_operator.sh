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

pick_team_from_list() {
  phase2_menu__header "Phase 2 Operator" "Pick a team (Team 19 blocked)"
  phase2_menu__divider
  local t
  for t in $(seq 1 20); do
    if phase2_is_blocked_team "$t"; then
      echo "  - Team${t} [BLOCKED]"
    else
      echo "  - Team${t}"
    fi
  done
  echo ""
  local chosen
  chosen="$(phase2_menu__ask "Enter team number")"
  phase2_validate_team "$chosen" || return 1
  echo "$chosen"
}

pick_scope() {
  phase2_menu__header "Phase 2 Operator" "Single Entry Point"
  phase2_menu__divider
  phase2_menu__print_kv "Note" "Team 19 is blocked"
  echo ""
  phase2_menu__choose "Select target scope" 1 \
    "Current team (if saved)" \
    "Enter a team number" \
    "Pick from list (1-20, Team19 blocked)" \
    "All teams (1-20, Team19 blocked)" \
    "Exit"
}

run_for_team() {
  local team="$1"
  phase2_validate_team "$team" || { phase2_warn "Invalid or blocked team: $team"; return 1; }
  phase2_save_last_team "$team" || true
  set_intel_out_dir "$team"
  "$MAIN"
}

run_all_teams() {
  local action
  action="$(phase2_menu__choose "All teams: choose action" 1 \
    "Targets summary only (phase2_targets.sh)" \
    "Cancel")"
  case "$action" in
    0|2) return 0 ;;
    1)
      if [[ ! -x "${PHASE_DIR}/phase2_targets.sh" ]]; then
        phase2_warn "phase2_targets.sh not found or not executable."
        return 1
      fi
      local t
      for t in $(seq 1 20); do
        if phase2_is_blocked_team "$t"; then
          continue
        fi
        set_intel_out_dir "$t"
        phase2_save_last_team "$t" || true
        PHASE2_BATCH=1 "${PHASE_DIR}/phase2_targets.sh" "$t" || true
      done
      return 0
      ;;
  esac
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
      t="$(pick_team_from_list)" || exit 1
      run_for_team "$t"
      ;;
    4)
      run_all_teams || true
      ;;
    0|5)
      exit 0
      ;;
  esac
}

main "$@"
