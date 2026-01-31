#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_team_scanning.sh
# Purpose : Phase 1 Coordinator (Recon & Access, read-only)
# Version : 0.3.0
#
# Usage:
#   ./phase1_team_scanning.sh
#   ./phase1_team_scanning.sh <TEAM_NUMBER>
#
# Outputs:
#   ./logs/phase1_team_scanning.log
#   ./output/phase1_team_report.txt
#   plus whatever the child scripts write under ./output/
# ============================================================

TEAM_ARG="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "${SCRIPT_DIR}/lib" ]] || SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---- Import libs ----
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_runtime.sh" || { echo "ERROR: Missing lib/ccdc_runtime.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_utils.sh"   || { echo "ERROR: Missing lib/ccdc_utils.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_menu.sh"    || { echo "ERROR: Missing lib/ccdc_menu.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_net_scheme.sh" || { echo "ERROR: Missing lib/ccdc_net_scheme.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_error.sh" || true

TEAM=""
REPORT_OUT=""

usage() {
  ccdc__usage_team "$(basename "$0")"
}

require_child() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    if declare -F ccdc_err_die >/dev/null 2>&1; then
      ccdc_err_die "${E_IO}" "Missing required script: $path"
    else
      ccdc__die "Missing required script: $path" || true
      return 1
    fi
  fi
  [[ -x "$path" ]] || chmod +x "$path" 2>/dev/null || true
  return 0
}

run_child() {
  # Run a child script with TEAM and log outcome.
  local label="$1"
  local path="$2"

  require_child "$path" || return 1

  ccdc__section "Run: $label"
  ccdc__log "[*] Exec: $path $TEAM"

  if "$path" "$TEAM"; then
    ccdc__log "[+] OK: $label"
    return 0
  fi

  ccdc__warn "FAIL: $label"
  return 1
}

write_report() {
  REPORT_OUT="${CCDC_OUT_DIR}/phase1_team_report.txt"
  : > "$REPORT_OUT"

  local subnet
  subnet="$(ccdc__target_net "$TEAM")"
  local services_csv services_hits targets_cand web_fp_csv
  services_csv="${CCDC_OUT_DIR}/services.csv"
  services_hits="${CCDC_OUT_DIR}/services_hits.txt"
  targets_cand="${CCDC_OUT_DIR}/targets_candidates.txt"
  web_fp_csv="${CCDC_OUT_DIR}/web_fingerprint.csv"
  local count_services count_hits count_cand count_fp
  count_services="N/A"
  count_hits="N/A"
  count_cand="N/A"
  count_fp="N/A"
  if [[ -f "$services_csv" ]]; then
    count_services="$(awk -F',' 'NR>1 {c++} END {print c+0}' "$services_csv" 2>/dev/null)"
  fi
  if [[ -f "$services_hits" ]]; then
    count_hits="$(awk 'NF>0 {c++} END {print c+0}' "$services_hits" 2>/dev/null)"
  fi
  if [[ -f "$targets_cand" ]]; then
    count_cand="$(awk 'NF>0 {c++} END {print c+0}' "$targets_cand" 2>/dev/null)"
  fi
  if [[ -f "$web_fp_csv" ]]; then
    count_fp="$(awk -F',' 'NR>1 {c++} END {print c+0}' "$web_fp_csv" 2>/dev/null)"
  fi

  {
    echo "Phase 1 -- Recon & Access Report"
    echo "Time: $(ccdc__now)"
    echo "Team: ${TEAM}"
    echo "Subnet: ${subnet}"
    echo ""
    echo "Generated Outputs (expected):"
    echo "  - ${CCDC_OUT_DIR}/cred_ledger.md"
    echo "  - ${CCDC_OUT_DIR}/service_map.md"
    echo "  - ${CCDC_OUT_DIR}/targets_watchlist.md"
    echo "  - ${CCDC_OUT_DIR}/services.txt"
    echo "  - ${CCDC_OUT_DIR}/services.csv"
    echo "  - ${CCDC_OUT_DIR}/services_hits.txt"
    echo "  - ${CCDC_OUT_DIR}/targets_candidates.txt"
    echo "  - ${CCDC_OUT_DIR}/web_fingerprint.txt"
    echo "  - ${CCDC_OUT_DIR}/web_fingerprint.csv"
    echo ""
    echo "Quick Counts:"
    echo "  - Services (CSV rows):     ${count_services}"
    echo "  - Service hits:            ${count_hits}"
    echo "  - Candidate targets:       ${count_cand}"
    echo "  - Web fingerprint entries: ${count_fp}"
    echo ""
    echo "Quick Workflow:"
    echo "  1) Run Service Inventory -> identify likely OpenCart/Webmail/Splunk"
    echo "  2) Run Web Fingerprint -> confirm app hints + likely admin/login paths"
    echo "  3) Update targets_watchlist.md + cred_ledger.md as creds appear"
    echo ""
    echo "Notes:"
    echo "  - This coordinator is Phase 1 only (read-only recon)."
  } >> "$REPORT_OUT"

  ccdc__log "[*] Wrote report: $REPORT_OUT"
}

run_all() {
  # Runs all phase 1 steps and records a status summary.
  local ok_cred="FAIL" ok_inv="FAIL" ok_fp="FAIL"

  if run_child "Initialize ledgers/docs" "${SCRIPT_DIR}/phase1_cred_ledger_init.sh"; then ok_cred="OK"; fi
  if run_child "Service Inventory (HTTP/HTTPS)" "${SCRIPT_DIR}/phase1_service_inventory.sh"; then ok_inv="OK"; fi
  if run_child "Web Fingerprint" "${SCRIPT_DIR}/phase1_web_fingerprint.sh"; then ok_fp="OK"; fi

  write_report || true

  {
    echo ""
    echo "Run Status:"
    echo "  cred_ledger_init: $ok_cred"
    echo "  service_inventory: $ok_inv"
    echo "  web_fingerprint:  $ok_fp"
    echo ""
  } >> "$REPORT_OUT" 2>/dev/null || true

  ccdc__log "[*] All-steps run complete. Status: ledger=$ok_cred inventory=$ok_inv fingerprint=$ok_fp"
}

view_outputs_menu() {
  local choice file
  while true; do
    ccdc_menu__header "Phase 1 -- View Outputs" "Choose a file to view"
    choice="$(ccdc_menu__choose "Select output" 1 \
      "phase1_team_report.txt" \
      "cred_ledger.md" \
      "targets_watchlist.md" \
      "services_hits.txt" \
      "services.txt" \
      "services.csv" \
      "targets_candidates.txt" \
      "web_fingerprint.txt" \
      "web_fingerprint.csv" \
      "Back")"

    case "$choice" in
      1) file="${CCDC_OUT_DIR}/phase1_team_report.txt" ;;
      2) file="${CCDC_OUT_DIR}/cred_ledger.md" ;;
      3) file="${CCDC_OUT_DIR}/targets_watchlist.md" ;;
      4) file="${CCDC_OUT_DIR}/services_hits.txt" ;;
      5) file="${CCDC_OUT_DIR}/services.txt" ;;
      6) file="${CCDC_OUT_DIR}/services.csv" ;;
      7) file="${CCDC_OUT_DIR}/targets_candidates.txt" ;;
      8) file="${CCDC_OUT_DIR}/web_fingerprint.txt" ;;
      9) file="${CCDC_OUT_DIR}/web_fingerprint.csv" ;;
      0|10) return 0 ;;
    esac

    ccdc__open_viewer "$file" || true
    ccdc_menu__pause
  done
}

menu_loop() {
  while true; do
    ccdc_menu__header "Phase 1 -- Team Recon Coordinator" "Read-only Recon & Access"
    ccdc__log_kv "Team" "$TEAM"
    ccdc__log_kv "Public subnet" "$(ccdc__target_net "$TEAM")"
    ccdc__log_kv "Output dir" "${CCDC_OUT_DIR}"
    echo ""

    local choice
    choice="$(ccdc_menu__choose "Select action" 1 \
      "Run: Initialize ledgers/docs" \
      "Run: Service Inventory (HTTP/HTTPS only)" \
      "Run: Web Fingerprint (low-noise)" \
      "Run: All Phase 1 steps" \
      "Write/Refresh Phase 1 report" \
      "View outputs" \
      "View coordinator log" \
      "Exit")"

    case "$choice" in
      1) run_child "Initialize ledgers/docs" "${SCRIPT_DIR}/phase1_cred_ledger_init.sh"; ccdc_menu__pause ;;
      2) run_child "Service Inventory (HTTP/HTTPS)" "${SCRIPT_DIR}/phase1_service_inventory.sh"; ccdc_menu__pause ;;
      3) run_child "Web Fingerprint" "${SCRIPT_DIR}/phase1_web_fingerprint.sh"; ccdc_menu__pause ;;
      4) run_all; ccdc_menu__pause ;;
      5) write_report; ccdc_menu__pause ;;
      6) view_outputs_menu ;;
      7) ccdc__open_viewer "${CCDC_LOG_FILE}" || true; ccdc_menu__pause ;;
      0|8) return 0 ;;
    esac
  done
}

main() {
  ccdc__init_run "phase1_team_scanning" || exit 1

  TEAM=""
  if TEAM_PARSED="$(ccdc__parse_team_or_last "$TEAM_ARG" 2>/dev/null)"; then
    TEAM="$TEAM_PARSED"
  fi

  # Ensure Phase 1 scripts exist
  require_child "${SCRIPT_DIR}/phase1_cred_ledger_init.sh" || exit 3
  require_child "${SCRIPT_DIR}/phase1_service_inventory.sh" || exit 3
  require_child "${SCRIPT_DIR}/phase1_web_fingerprint.sh" || exit 3

  if ccdc_menu__is_interactive; then
    TEAM="$(ccdc_menu__pick_team "$TEAM" "0")" || return 0
    ccdc_net__warn_if_team_out_of_range "$TEAM" || true
    ccdc__log_kv "Mapping" "$(ccdc_net__mapping_source)"
    ccdc__save_last_team "$TEAM" || ccdc__warn "Could not save output/team.txt (continuing)"
    ccdc__set_team_output_dir "$TEAM" || ccdc__warn "Could not set team output dir (continuing)"

    # Create report path now that team output dir is set
    REPORT_OUT="${CCDC_OUT_DIR}/phase1_team_report.txt"
    [[ -f "$REPORT_OUT" ]] || : > "$REPORT_OUT"

    # Log network scheme summary (helps operator orientation)
    ccdc__section "Team Network Summary"
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

    # Create report path now that team output dir is set
    REPORT_OUT="${CCDC_OUT_DIR}/phase1_team_report.txt"
    [[ -f "$REPORT_OUT" ]] || : > "$REPORT_OUT"
    ccdc__section "Team Network Summary"
    ccdc_net__print_team_summary "$TEAM" || true
    run_all || true
  fi

  return 0
}

main
