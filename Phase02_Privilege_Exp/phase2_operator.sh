#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase2_operator.sh
# Purpose : Phase 2 Operator Single Entry Point
# Run     : ./phase2_operator.sh
#          ./phase2_operator.sh --team 3 --preset fast
#          ./phase2_operator.sh --all --preset fast
# ============================================================

PHASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${PHASE_DIR}/lib"
MAIN="${PHASE_DIR}/tools/phase2_privilege_main.sh"

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

PRESET=""
MODE=""
TEAM_ARG=""

usage() {
  echo "Usage:"
  echo "  ./phase2_operator.sh"
  echo "  ./phase2_operator.sh --team <N> [--preset fast|normal|full]"
  echo "  ./phase2_operator.sh --all [--preset fast|normal|full]"
}

apply_preset() {
  local preset="${1^^}"
  case "$preset" in
    FAST)
      export PHASE2_HTTP_CONNECT_TIMEOUT="2"
      export PHASE2_HTTP_TIMEOUT_SECS="4"
      export PHASE2_SSH_CONNECT_TIMEOUT="3"
      ;;
    NORMAL)
      export PHASE2_HTTP_CONNECT_TIMEOUT="3"
      export PHASE2_HTTP_TIMEOUT_SECS="8"
      export PHASE2_SSH_CONNECT_TIMEOUT="5"
      ;;
    FULL)
      export PHASE2_HTTP_CONNECT_TIMEOUT="5"
      export PHASE2_HTTP_TIMEOUT_SECS="15"
      export PHASE2_SSH_CONNECT_TIMEOUT="8"
      ;;
    "") ;;
    *) phase2_warn "Unknown preset: $preset"; return 1 ;;
  esac
  export PHASE2_PRESET="$preset"
  return 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --team) TEAM_ARG="${2:-}"; MODE="team"; shift 2 ;;
      --all) MODE="all"; shift ;;
      --preset) PRESET="${2:-}"; shift 2 ;;
      --fast) PRESET="FAST"; shift ;;
      --normal) PRESET="NORMAL"; shift ;;
      --full) PRESET="FULL"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) phase2_warn "Unknown arg: $1"; usage; exit 1 ;;
    esac
  done
}

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
      echo "  - Team${t} [BLOCKED]" >&2
    else
      echo "  - Team${t}" >&2
    fi
  done
  echo "" >&2
  local chosen
  chosen="$(phase2_menu__ask "Enter team number")"
  phase2_validate_team "$chosen" || return 1
  echo "$chosen"
}

pick_teams_multi() {
  phase2_menu__header "Phase 2 Operator" "Pick multiple teams (comma-separated)"
  phase2_menu__divider
  echo "Examples: 1,2,3 or 4,7,12" >&2
  echo "Team 19 is blocked." >&2
  local raw
  raw="$(phase2_menu__ask "Enter team numbers")"
  raw="$(echo "$raw" | tr -d ' ')" # remove spaces
  [[ -n "$raw" ]] || return 1

  local tlist=()
  local IFS=','
  read -r -a parts <<< "$raw"
  for t in "${parts[@]}"; do
    [[ -n "$t" ]] || continue
    phase2_validate_team "$t" || { phase2_warn "Invalid team: $t"; return 1; }
    tlist+=("$t")
  done
  echo "${tlist[@]}"
}

pick_scope() {
  phase2_menu__header "Phase 2 Operator" "Single Entry Point"
  phase2_menu__divider
  phase2_menu__print_kv "Note" "Team 19 is blocked"
  echo "" >&2
  phase2_menu__choose "Select target scope" 1 \
    "Single team" \
    "Group of teams (multi-select)" \
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
  # Default to targets summary for all teams.
  local mode="${1:-targets}"

  if [[ "${PHASE2_ALL_PROMPT:-0}" == "1" ]]; then
    local action
    action="$(phase2_menu__choose "All teams: choose action" 1 \
      "Targets summary only (phase2_targets.sh)" \
      "Cancel")"
    case "$action" in
      0|2) return 0 ;;
      1) mode="targets" ;;
    esac
  fi

  if [[ "$mode" == "targets" ]]; then
    if [[ ! -x "${PHASE_DIR}/tools/phase2_targets.sh" ]]; then
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
      PHASE2_BATCH=1 "${PHASE_DIR}/tools/phase2_targets.sh" "$t" || true
    done
    return 0
  fi

  phase2_warn "Unknown all-teams mode: $mode"
  return 1
}

main() {
  phase2_init_run "phase2_operator" || true
  parse_args "$@"
  [[ -n "$PRESET" ]] && apply_preset "$PRESET" || true

  if [[ "$MODE" == "team" ]]; then
    [[ -n "$TEAM_ARG" ]] || { phase2_warn "Missing team number."; usage; exit 1; }
    phase2_validate_team "$TEAM_ARG" || exit 1
    run_for_team "$TEAM_ARG"
    exit 0
  fi

  if [[ "$MODE" == "all" ]]; then
    export PHASE2_BATCH=1
    export PHASE2_BRIEF=1
    run_all_teams || true
    exit 0
  fi

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
      PHASE2_BRIEF=1 run_all_teams "targets" || true
      ;;
    0|4)
      exit 0
      ;;
  esac
}

main "$@"
