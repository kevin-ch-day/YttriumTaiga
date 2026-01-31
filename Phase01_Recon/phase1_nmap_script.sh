#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_nmap_script.sh
# Purpose : Phase 1 - Nmap workflow assistant (read-only helper)
# Version : 0.2.0
#
# Usage:
#   ./phase1_nmap_script.sh
#   ./phase1_nmap_script.sh <TEAM_NUMBER>
#
# Output:
#   ./logs/phase1_nmap_script.log
#   ./output/nmap/commands.txt
#   ./output/nmap/results/          (place your nmap outputs here)
#   ./output/nmap/targets_live.txt  (host list you maintain)
#
# Notes:
# - This script does NOT run scans itself.
# - It helps you organize, document, and reuse a Phase 1 recon workflow.
# ============================================================

TEAM_ARG="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Import libs ----
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_runtime.sh" || { echo "ERROR: Missing lib/ccdc_runtime.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_utils.sh"   || { echo "ERROR: Missing lib/ccdc_utils.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_menu.sh"    || { echo "ERROR: Missing lib/ccdc_menu.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_net_scheme.sh" || { echo "ERROR: Missing lib/ccdc_net_scheme.sh"; exit 3; }

TEAM=""
BASE_DIR=""
CMD_FILE=""
TARGETS_FILE=""
RESULTS_DIR=""

usage() { ccdc__usage_team "$(basename "$0")"; }

init_paths() {
  BASE_DIR="${CCDC_OUT_DIR}/nmap"
  RESULTS_DIR="${BASE_DIR}/results"
  CMD_FILE="${BASE_DIR}/commands.txt"
  TARGETS_FILE="${BASE_DIR}/targets_live.txt"

  mkdir -p "$RESULTS_DIR" 2>/dev/null || true
  [[ -f "$CMD_FILE" ]] || : > "$CMD_FILE"
  [[ -f "$TARGETS_FILE" ]] || : > "$TARGETS_FILE"
}

write_command_worksheet() {
  : > "$CMD_FILE"

  local pub
  pub="$(ccdc__target_net "$TEAM")"

  {
    echo "# Phase 1 -- Nmap Worksheet (copy/paste commands you choose to run)"
    echo "# Time: $(ccdc__now)"
    echo "# Team: ${TEAM}"
    echo "# Public subnet: ${pub}"
    echo ""
    echo "# Suggested file naming (save into ./output/nmap/results/):"
    echo "#   ping_sweep.txt"
    echo "#   top_ports.txt"
    echo "#   web_ports.txt"
    echo "#   smb_ports.txt"
    echo ""
    echo "# Host discovery / reachability (choose what rules allow):"
    echo "#   nmap -sn ${pub} -oN ${RESULTS_DIR}/ping_sweep.txt"
    echo ""
    echo "# Focused service checks (low-noise, high value):"
    echo "#   nmap -sT -p 80,443 ${pub} -oN ${RESULTS_DIR}/web_ports.txt"
    echo "#   nmap -sT -p 445 ${pub} -oN ${RESULTS_DIR}/smb_ports.txt"
    echo "#   nmap -sT -p 22 ${pub} -oN ${RESULTS_DIR}/ssh_ports.txt"
    echo ""
    echo "# Tip:"
    echo "# - Keep Phase 1 low-noise. Prefer focused ports and short runs."
    echo "# - Use your HTTP inventory scripts first when possible."
  } >> "$CMD_FILE"

  ccdc__log "[*] Wrote worksheet: $CMD_FILE"
}

extract_hosts_from_ping_sweep() {
  # Extract hosts from an nmap -sn output if the file exists.
  local in_file="${RESULTS_DIR}/ping_sweep.txt"
  if [[ ! -f "$in_file" ]]; then
    ccdc__warn "Missing ${in_file}. Run your chosen discovery command and save output there."
    return 1
  fi

  if ! command -v awk >/dev/null 2>&1 || ! command -v sort >/dev/null 2>&1; then
    ccdc__warn "Missing awk/sort; cannot extract targets."
    return 1
  fi

  # Nmap output usually has: "Nmap scan report for <ip>"
  awk '/Nmap scan report for/ {print $NF}' "$in_file" 2>/dev/null | sort -u > "$TARGETS_FILE" || true
  ccdc__log "[*] Updated targets: $TARGETS_FILE"
  return 0
}

menu_loop() {
  while true; do
    ccdc_menu__header "Phase 1 -- Nmap Workflow Assistant" "Organize recon commands + results (no scans run)"
    ccdc__log_kv "Team" "$TEAM"
    ccdc__log_kv "Public subnet" "$(ccdc__target_net "$TEAM")"
    ccdc__log_kv "Workspace" "$BASE_DIR"
    echo ""

    local choice
    choice="$(ccdc_menu__choose "Select action" 1 \
      "Generate/refresh commands worksheet" \
      "Open commands worksheet" \
      "Extract targets from results/ping_sweep.txt" \
      "Open targets_live.txt" \
      "Open results folder listing" \
      "Exit")"

    case "$choice" in
      1) write_command_worksheet; ccdc_menu__pause ;;
      2) ccdc__open_viewer "$CMD_FILE" || true; ccdc_menu__pause ;;
      3) extract_hosts_from_ping_sweep || true; ccdc_menu__pause ;;
      4) ccdc__open_viewer "$TARGETS_FILE" || true; ccdc_menu__pause ;;
      5) (ls -lah "$RESULTS_DIR" 2>/dev/null || true) | sed 's/^/[results] /'; ccdc_menu__pause ;;
      0|6) return 0 ;;
    esac
  done
}

main() {
  ccdc__init_run "phase1_nmap_script" || exit 1

  TEAM="$(ccdc__parse_team_or_last "$TEAM_ARG")" || { usage; return 1; }
  ccdc__save_last_team "$TEAM" || ccdc__warn "Could not save output/team.txt (continuing)"

  init_paths

  ccdc__section "Team Network Summary"
  ccdc_net__print_team_summary "$TEAM" || true

  if ccdc_menu__is_interactive; then
    menu_loop
  else
    write_command_worksheet
  fi

  return 0
}

main
