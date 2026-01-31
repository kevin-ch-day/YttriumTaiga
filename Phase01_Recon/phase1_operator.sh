#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_operator.sh
# Purpose : Phase 1 Operator Single Entry Point
# Run     : ./phase1_operator.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"
RECON="${TOOLS_DIR}/phase1_team_scanning.sh"

# ---- Import Phase01 libs for consistent menus + rules ----
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_runtime.sh" || { echo "ERROR: Missing lib/ccdc_runtime.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_utils.sh"   || { echo "ERROR: Missing lib/ccdc_utils.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_menu.sh"    || { echo "ERROR: Missing lib/ccdc_menu.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_net_scheme.sh" || { echo "ERROR: Missing lib/ccdc_net_scheme.sh"; exit 3; }

if [[ ! -x "$RECON" ]]; then
  echo "ERROR: Missing operator tool: $RECON" >&2
  exit 2
fi

pick_mode() {
  ccdc_menu__header "Phase 01 Operator" "Single Entry Point"
  echo "Select target scope:"
  local choice
  choice="$(ccdc_menu__choose "Scope" 1 \
    "Current team (if saved)" \
    "Enter a team number" \
    "All teams (1-20, Team19 blocked)" \
    "Exit")"
  echo "$choice"
}

select_team_single() {
  local last
  last="$(ccdc__load_last_team)"
  case "$(pick_mode)" in
    1)
      if [[ -n "$last" ]]; then
        echo "$last"
        return 0
      fi
      ccdc__warn "No saved team found; please enter a team."
      ;;
    2)
      local t
      t="$(ccdc_menu__ask "Enter team number")"
      [[ -n "$t" ]] || return 1
      ccdc__validate_team "$t" || return 1
      echo "$t"
      return 0
      ;;
    3)
      echo "ALL"
      return 0
      ;;
    0|4)
      return 1
      ;;
  esac
  return 1
}

run_all_for_team() {
  local team="$1"
  echo ""
  echo "=== Phase01: Team ${team} ==="
  "${RECON}" "$team"
}

main() {
  ccdc__init_run "phase1_operator" || exit 1

  local sel
  sel="$(select_team_single)" || exit 0

  if [[ "$sel" == "ALL" ]]; then
    local t
    for t in $(seq 1 20); do
      if ccdc__is_blocked_team "$t"; then
        continue
      fi
      run_all_for_team "$t"
    done
    exit 0
  fi

  run_all_for_team "$sel"
}

main "$@"
