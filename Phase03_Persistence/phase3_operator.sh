#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase3_operator.sh
# Purpose : Phase 3 Operator Single Entry Point
# Run     : ./phase3_operator.sh
# ============================================================

PHASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN="${PHASE_DIR}/tools/phase3_continuity.sh"

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
    local intel_override="${CCDC_INTEL_DIR:-}"
    # shellcheck disable=SC1090
    source "$rules" || true
    [[ -n "$intel_override" ]] && CCDC_INTEL_DIR="$intel_override"
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
  mkdir -p "$CCDC_OUT_DIR" 2>/dev/null || true
  export CCDC_OUT_DIR_BASE="${CCDC_OUT_DIR}"
}

pick_team_from_list() {
  ccdc_menu__header "Phase 3 Operator" "Pick a team (Team 19 blocked)"
  ccdc_menu__divider
  local t
  for t in $(seq 1 20); do
    if ccdc__is_blocked_team "$t"; then
      echo "  - Team${t} [BLOCKED]" >&2
    else
      echo "  - Team${t}" >&2
    fi
  done
  echo "" >&2
  local chosen
  chosen="$(ccdc_menu__ask "Enter team number")"
  ccdc__validate_team "$chosen" || return 1
  echo "$chosen"
}

pick_teams_multi() {
  ccdc_menu__header "Phase 3 Operator" "Pick multiple teams (comma-separated)"
  ccdc_menu__divider
  echo "Examples: 1,2,3 or 4,7,12" >&2
  echo "Team 19 is blocked." >&2
  local raw
  raw="$(ccdc_menu__ask "Enter team numbers")"
  raw="$(echo "$raw" | tr -d ' ')"
  [[ -n "$raw" ]] || return 1

  local tlist=()
  local IFS=','
  read -r -a parts <<< "$raw"
  for t in "${parts[@]}"; do
    [[ -n "$t" ]] || continue
    ccdc__validate_team "$t" || { ccdc__warn "Invalid team: $t"; return 1; }
    tlist+=("$t")
  done
  echo "${tlist[@]}"
}

pick_scope() {
  ccdc_menu__header "Phase 3 Operator" "Single Entry Point"
  ccdc_menu__divider
  ccdc_menu__print_kv "Note" "Team 19 is blocked"
  echo "" >&2
  ccdc_menu__choose "Select target scope" 1 \
    "Single team" \
    "Group of teams (multi-select)" \
    "All teams (1-20, Team19 blocked)" \
    "Exit"
}

run_for_team() {
  local team="$1"
  set_intel_out_dir "$team"
  ccdc__save_last_team "$team" || true
  CCDC_TEAM_LOCK=1 "$MAIN" "$team"
}

main() {
  ccdc__init_run "phase3_operator" || true
  local choice
  choice="$(pick_scope)" || exit 0
  case "$choice" in
    1)
      local t
      t="$(pick_team_from_list)" || exit 1
      run_for_team "$t"
      ;;
    2)
      local teams
      teams="$(pick_teams_multi)" || exit 1
      for t in $teams; do
        run_for_team "$t" || true
      done
      ;;
    3)
      local t
      for t in $(seq 1 20); do
        if ccdc__is_blocked_team "$t"; then
          continue
        fi
        set_intel_out_dir "$t"
        CCDC_BATCH=1 CCDC_BRIEF=1 CCDC_TEAM_LOCK=1 "$MAIN" "$t"
      done
      ;;
    0|4)
      exit 0
      ;;
  esac
}

main "$@"
