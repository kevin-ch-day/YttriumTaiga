#!/usr/bin/env bash
# Taconite core application launcher helpers.

taconite_phase_entry() {
  local phase="${1:-}"
  case "$phase" in
    0|00|setup) echo "Phase00_Setup/setup_kali_os.sh" ;;
    1|01|recon) echo "Phase01_Recon/phase1_operator.sh" ;;
    2|02|privilege|privexp) echo "Phase02_Privilege_Exp/phase2_operator.sh" ;;
    3|03|persistence|continuity) echo "Phase03_Persistence/phase3_operator.sh" ;;
    4|04|disruption) echo "Phase04_Controlled_Disruption/phase4_operator.sh" ;;
    5|05|kill) echo "Phase05_Kill_Service/phase5_operator.sh" ;;
    6|06|dayend|cleanup) echo "Phase06_Day_End/phase6_operator.sh" ;;
    *) return 1 ;;
  esac
}

taconite_phase_label() {
  local phase="${1:-}"
  case "$phase" in
    0|00|setup) echo "Phase 00 // Setup" ;;
    1|01|recon) echo "Phase 01 // Recon" ;;
    2|02|privilege|privexp) echo "Phase 02 // Privilege Expansion" ;;
    3|03|persistence|continuity) echo "Phase 03 // Continuity" ;;
    4|04|disruption) echo "Phase 04 // Controlled Disruption" ;;
    5|05|kill) echo "Phase 05 // Kill Service" ;;
    6|06|dayend|cleanup) echo "Phase 06 // Day End" ;;
    *) echo "Unknown phase" ;;
  esac
}

taconite_run_phase() {
  local phase="${1:-}"
  shift || true

  local root entry
  root="$(taconite_repo_root)" || return 1
  entry="$(taconite_phase_entry "$phase")" || {
    taconite_error "Unknown phase: $phase"
    return "$TACONITE_E_USAGE"
  }

  if [[ ! -f "${root}/${entry}" ]]; then
    taconite_error "Missing phase entry: ${entry}"
    return "$TACONITE_E_IO"
  fi

  taconite_frame "Taconite Launch" "$(taconite_phase_label "$phase")" "accent"
  taconite_kv "Entry" "$entry"
  exec "${root}/${entry}" "$@"
}

taconite_print_phase_list() {
  taconite_section "Phase registry"
  taconite_kv "00" "Setup"
  taconite_kv "01" "Recon"
  taconite_kv "02" "Privilege Expansion"
  taconite_kv "03" "Continuity"
  taconite_kv "04" "Controlled Disruption (stub)"
  taconite_kv "05" "Kill Service (stub)"
  taconite_kv "06" "Day End"
}
