#!/usr/bin/env bash
# phase2_targets.sh
set -euo pipefail

# ============================================================
# Phase 2 (Privilege Expansion) - Targets Helper
# Version : 0.1.0
#
# Purpose:
# - Resolve TEAM (arg or last saved)
# - Print subnet + key IPs using Phase 2 net scheme lib
# - Write a deterministic targets note under output/notes/
#
# Run:
#   chmod +x ./phase2_targets.sh
#   ./phase2_targets.sh            # uses last team if saved
#   ./phase2_targets.sh 21         # explicit team
# ============================================================

PHASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${PHASE_DIR}/lib"

# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_meta.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_runtime.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_utils.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_menu.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_net_scheme.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_intel.sh"

phase2_targets__notes_dir() {
  local out_dir
  out_dir="$(phase2__resolve_out_dir)" || return 1
  local sub="${OUT_SUBDIR_NOTES:-notes}"
  echo "${out_dir}/${sub}"
}

phase2_targets__write_report() {
  local team="$1"
  local report_path="$2"

  local oct pub transit cidr core_ip team_ip
  oct="$(ccdc_net__team_octet "$team" 2>/dev/null || true)"
  pub="$(ccdc_net__public_subnet "$team" 2>/dev/null || true)"
  cidr="$(ccdc_net__core_transit_cidr "$team" 2>/dev/null || true)"
  core_ip="$(ccdc_net__core_transit_router_ip "$team" 2>/dev/null || true)"
  team_ip="$(ccdc_net__core_transit_team_ip "$team" 2>/dev/null || true)"

  {
    echo "=== Phase 2 Targets Summary ==="
    echo "Phase: ${PHASE_NAME} v${PHASE_VERSION}"
    echo "Time:  $(phase2_now)"
    echo ""
    echo "Team:        ${team}"
    echo "Team octet:  ${oct}"
    echo "Public /24:  ${pub}"
    echo "Transit:     ${cidr}"
    echo "Core IP:     ${core_ip}"
    echo "Team IP:     ${team_ip}"
    echo ""
    echo "Candidate public hosts (common ports/services):"
    echo "------------------------------------------------------------"
    ccdc_net__public_host_candidates "$team" 2>/dev/null || true
    echo ""
    echo "Notes:"
    echo "- Phase 2 goal: turn access into control (creds, remote exec, privesc)."
    echo "- Use this list for focused checks (SSH/HTTP/admin portals) rather than broad scans."
    echo ""
    echo "Phase 1 Intel (if available):"
    phase2_intel__summary_plain "$team" 2>/dev/null || true
  } > "$report_path"
}

main() {
  phase2_init_run "phase2_targets" || {
    echo "ERROR: failed to init Phase 2 runtime" >&2
    exit 1
  }

  local team_arg="${1:-}"
  local team=""
  if team="$(phase2_parse_team_or_last "$team_arg" 2>/dev/null)"; then
    :
  else
    phase2_warn "No team provided and no saved team found."
    phase2_usage_team "$(basename "$0")"
    exit 1
  fi

  ccdc_net__warn_if_team_out_of_range "$team" || true
  phase2_log_kv "Mapping" "$(ccdc_net__mapping_source)"

  # Save for later scripts
  phase2_save_last_team "$team" || true

  phase2_section "Team Network Summary"
  ccdc_net__print_team_summary "$team" || {
    phase2_warn "Could not print team summary (net scheme issue)."
  }

  # Write deterministic note
  local notes_dir report_path
  notes_dir="$(phase2_targets__notes_dir)"
  mkdir -p "$notes_dir" 2>/dev/null || true
  report_path="${notes_dir}/phase2_targets_team${team}.txt"

  phase2_targets__write_report "$team" "$report_path"
  phase2_log "[*] Wrote targets note: $report_path"

  # Offer to view it (skip in batch/non-interactive)
  if [[ "${PHASE2_BATCH:-0}" != "1" ]] && phase2_menu__is_interactive; then
    if phase2_menu__confirm "Open targets note nowNO" "Y"; then
      phase2_open_viewer "$report_path" || true
    fi
  fi

  return 0
}

main "$@"
