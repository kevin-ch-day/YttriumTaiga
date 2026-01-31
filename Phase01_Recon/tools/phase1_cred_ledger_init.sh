#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_cred_ledger_init.sh
# Purpose : Phase 1 - Initialize credential + service tracking docs
# Version : 0.3.0
#
# Usage:
#   ./phase1_cred_ledger_init.sh
#   ./phase1_cred_ledger_init.sh <TEAM_NUMBER>
#
# Output (Phase 1 dirs):
#   ./logs/phase1_cred_ledger_init.log
#   ./output/cred_ledger.csv
#   ./output/service_map.csv
#   ./output/targets_watchlist.csv
# ============================================================

TEAM_ARG="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# If invoked from tools/, base dir is parent.
[[ -d "${SCRIPT_DIR}/lib" ]] || SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---- Import libs (Phase 1 local lib only) ----
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_runtime.sh" || { echo "ERROR: Missing lib/ccdc_runtime.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_utils.sh"   || { echo "ERROR: Missing lib/ccdc_utils.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_menu.sh"    || { echo "ERROR: Missing lib/ccdc_menu.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_net_scheme.sh" || { echo "ERROR: Missing lib/ccdc_net_scheme.sh"; exit 3; }

OUT_CRED=""
OUT_MAP=""
OUT_WATCH=""

usage() {
  ccdc__usage_team "$(basename "$0")"
}

set_team_interactive() {
  local ans=""
  ans="$(ccdc_menu__ask "Enter team number (blank = keep unset)" "${TEAM:-}")"
  [[ -n "$ans" ]] || return 1
  if ! ccdc__validate_team "$ans"; then
    ccdc__warn "Invalid team number: $ans"
    return 1
  fi
  TEAM="$ans"
  ccdc_net__warn_if_team_out_of_range "$TEAM" || true
  ccdc__log_kv "Mapping" "$(ccdc_net__mapping_source)"
  ccdc__save_last_team "$TEAM" || ccdc__warn "Could not save output/team.txt (continuing)"
  return 0
}

ensure_team_for_templates() {
  if [[ -z "${TEAM:-}" ]]; then
    ccdc__warn "Team not set. Use 'Set/Change team' first."
    return 1
  fi
  return 0
}

build_templates() {
  local team="$1"
  ccdc__validate_team "$team" || { ccdc__warn "Invalid team number: $team"; return 1; }
  local pub_subnet
  pub_subnet="$(ccdc__target_net "$team")"

  local cred_ledger service_map watchlist

  cred_ledger="$(cat <<'EOF'
time,source,username,password_or_token,auth_type,role_guess,tested_where,result,notes
EOF
)"

  service_map="$(cat <<EOF
# Team ${team} | Public subnet: ${pub_subnet}
public_ip,hostname_hint,service,port,tech_headers,auth_surface,notes
EOF
)"

  watchlist="$(cat <<EOF
suspected_system,public_ip,evidence,priority,notes
OpenCart (e-commerce),,,"High",
Webmail,,,"High",
Splunk,,,"Medium",
Windows Web,,,"Medium",
EOF
)"

  ccdc__section "Writing templates"
  ccdc__write_file_safe "$OUT_CRED" "$cred_ledger" || return 1
  ccdc__write_file_safe "$OUT_MAP" "$service_map" || return 1
  ccdc__write_file_safe "$OUT_WATCH" "$watchlist" || return 1

  return 0
}

open_docs_menu() {
  local choice file
  while true; do
    ccdc_menu__header "Phase 1 -- Docs" "Open generated docs"
    choice="$(ccdc_menu__choose "Select file" 1 \
      "cred_ledger.csv" \
      "service_map.csv" \
      "targets_watchlist.csv" \
      "Back")"

    case "$choice" in
      1) file="$OUT_CRED" ;;
      2) file="$OUT_MAP" ;;
      3) file="$OUT_WATCH" ;;
      0|4) return 0 ;;
    esac

    ccdc__open_viewer "$file" || true
    ccdc_menu__pause
  done
}

menu_loop() {
  while true; do
    ccdc_menu__header "Phase 1 -- Credential/Service Docs" "Initialize your working notes"
    if [[ -n "${TEAM:-}" ]]; then
      ccdc__log_kv "Team" "$TEAM"
      ccdc__log_kv "Public subnet" "$(ccdc__target_net "$TEAM")"
    else
      ccdc__log_kv "Team" "(unset)"
      ccdc__log_kv "Public subnet" "(unset)"
    fi
    ccdc__log_kv "Output dir" "${CCDC_OUT_DIR}"
    echo ""

    local choice default_choice
    if [[ -n "${TEAM:-}" ]]; then
      default_choice=2
    else
      default_choice=1
    fi
    choice="$(ccdc_menu__choose "Select action" "$default_choice" \
      "Set/Change team number" \
      "Generate templates (safe-write)" \
      "Open templates" \
      "Exit")"

    case "$choice" in
      1) set_team_interactive || true; ccdc_menu__pause ;;
      2) ensure_team_for_templates && build_templates "$TEAM"; ccdc_menu__pause ;;
      3) open_docs_menu ;;
      0|4) return 0 ;;
    esac
  done
}

main() {
  ccdc__init_run "phase1_cred_ledger_init" || exit 1

  # Resolve team: arg -> last saved (if available).
  TEAM=""
  if TEAM_PARSED="$(ccdc__parse_team_or_last "$TEAM_ARG" 2>/dev/null)"; then
    TEAM="$TEAM_PARSED"
  fi

  if ccdc_menu__is_interactive; then
    TEAM="$(ccdc_menu__pick_team "$TEAM" "0")" || return 0
    ccdc_net__warn_if_team_out_of_range "$TEAM" || true
    ccdc__log_kv "Mapping" "$(ccdc_net__mapping_source)"
    ccdc__save_last_team "$TEAM" || ccdc__warn "Could not save output/team.txt (continuing)"
    ccdc__set_team_output_dir "$TEAM" || ccdc__warn "Could not set team output dir (continuing)"

    # Output paths (fixed names)
  OUT_CRED="${CCDC_OUT_DIR}/cred_ledger.csv"
  OUT_MAP="${CCDC_OUT_DIR}/service_map.csv"
  OUT_WATCH="${CCDC_OUT_DIR}/targets_watchlist.csv"

    ccdc__section "Phase 1 Doc Init"
    ccdc__log_kv "Team" "$TEAM"
    ccdc_net__print_team_summary "$TEAM" || true
    menu_loop
  else
    if [[ -z "${TEAM:-}" ]]; then
      usage
      return 1
    fi
    ccdc_net__warn_if_team_out_of_range "$TEAM" || true
    ccdc__log_kv "Mapping" "$(ccdc_net__mapping_source)"
    ccdc__save_last_team "$TEAM" || ccdc__warn "Could not save output/team.txt (continuing)"
    ccdc__set_team_output_dir "$TEAM" || ccdc__warn "Could not set team output dir (continuing)"

    # Output paths (fixed names)
    OUT_CRED="${CCDC_OUT_DIR}/cred_ledger.md"
    OUT_MAP="${CCDC_OUT_DIR}/service_map.md"
    OUT_WATCH="${CCDC_OUT_DIR}/targets_watchlist.md"

    ccdc__section "Phase 1 Doc Init"
    ccdc__log_kv "Team" "$TEAM"
    ccdc_net__print_team_summary "$TEAM" || true
    build_templates "$TEAM"
  fi

  ccdc__section "Done"
  ccdc__log "[*] Files under: ${CCDC_OUT_DIR}"
  ccdc__log "    - $OUT_CRED"
  ccdc__log "    - $OUT_MAP"
  ccdc__log "    - $OUT_WATCH"
  return 0
}

main
