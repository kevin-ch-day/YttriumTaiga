#!/usr/bin/env bash
# phase2_privilege_main.sh
set -euo pipefail

# ============================================================
# Phase 2 (Privilege Expansion) - Main Entry Point
# Version : 0.1.0
#
# Purpose:
# - Single entry point for Phase 2 workflows
# - Uses Phase 2 libs and delegates to sub-scripts (targets/creds/remote/privesc)
#
# Expected sibling scripts (create next):
# - phase2_targets.sh
# - phase2_creds_ops.sh
# - phase2_remote_privesc.sh
#
# Run:
#   chmod +x ./phase2_privilege_main.sh
#   ./phase2_privilege_main.sh
# ============================================================

PHASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${PHASE_DIR}/lib"

# -----------------------------
# Source Phase 2 libs (meta first)
# -----------------------------
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
source "${LIB_DIR}/phase2_lib_http.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_creds.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_remote.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_privesc.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_intel.sh"

# -----------------------------
# Sub-script paths (Phase 2 local)
# -----------------------------
SCRIPT_TARGETS="${PHASE_DIR}/phase2_targets.sh"
SCRIPT_CREDS="${PHASE_DIR}/phase2_creds_ops.sh"
SCRIPT_REMOTE="${PHASE_DIR}/phase2_remote_privesc.sh"

phase2_main__have_script() { [[ -f "$1" ]]; }

phase2_main__run_script() {
  local script="${1:-}"
  shift || true
  if [[ -z "$script" || ! -f "$script" ]]; then
    phase2_warn "Missing script: $script"
    return 1
  fi
  if [[ ! -x "$script" ]]; then
    phase2_warn "Script not executable: $script (try: chmod +x \"$script\")"
    return 1
  fi

  phase2_log "[*] Launch -> $(basename "$script") $*"
  "$script" "$@"
}

phase2_main__show_paths() {
  phase2_section "Phase 2 Paths"
  phase2_log_kv "Phase" "${PHASE_NAME} v${PHASE_VERSION}"
  phase2_log_kv "Base" "${PHASE2_BASE_DIR:-$PHASE_DIR}"
  phase2_log_kv "Logs" "${PHASE2_LOG_DIR:-${PHASE_DIR}/${PHASE_LOG_DIR:-logs}}"
  phase2_log_kv "Output" "${PHASE2_OUT_DIR:-${PHASE_DIR}/${PHASE_OUT_DIR:-output}}"

  local loot_dir proof_dir enum_dir
  loot_dir="$(phase2_creds__resolve_loot_dir 2>/dev/null || true)"
  proof_dir="$(phase2_remote__proof_dir 2>/dev/null || true)"
  enum_dir="$(phase2_privesc__enum_dir 2>/dev/null || true)"

  [[ -n "$loot_dir" ]] && phase2_log_kv "Loot" "$loot_dir"
  [[ -n "$proof_dir" ]] && phase2_log_kv "Proof" "$proof_dir"
  [[ -n "$enum_dir" ]] && phase2_log_kv "Enum" "$enum_dir"
}

phase2_main__self_check() {
  phase2_section "Phase 2 Self-Check"
  phase2_log "[*] Checking required tools..."
  if declare -p REQUIRED_TOOLS >/dev/null 2>&1; then
    phase2_require_cmds "${REQUIRED_TOOLS[@]}" || true
  else
    phase2_warn "REQUIRED_TOOLS not defined in meta (continuing)"
  fi

  phase2_log "[*] Ensuring output dirs exist..."
  phase2_init_env || return 1

  local out_dir
  out_dir="$(phase2__resolve_out_dir 2>/dev/null || true)"
  [[ -n "$out_dir" ]] && mkdir -p "$out_dir" 2>/dev/null || true

  phase2_log "[*] Cred ledger init..."
  phase2_creds_init || true

  phase2_log "[*] Phase 1 intel check..."
  local t
  t="$(phase2_load_last_team 2>/dev/null || true)"
  if [[ -n "$t" ]]; then
    phase2_intel__summary "$t" || true
  else
    phase2_warn "No saved team for intel summary (run phase2_operator.sh to set team)."
  fi

  phase2_log "[*] OK"
}

phase2_main__intel_summary() {
  local t
  t="$(phase2_load_last_team 2>/dev/null || true)"
  if [[ -z "$t" ]]; then
    phase2_warn "No saved team. Set a team via phase2_operator.sh."
    return 1
  fi
  if ! phase2_validate_team "$t"; then
    phase2_warn "Saved team is invalid or blocked."
    return 1
  fi
  phase2_section "Phase 1 Intel Summary"
  phase2_intel__summary "$t" || return 1
  return 0
}

phase2_main__intel_import() {
  local t
  t="$(phase2_load_last_team 2>/dev/null || true)"
  if [[ -z "$t" ]]; then
    phase2_warn "No saved team. Set a team via phase2_operator.sh."
    return 1
  fi
  if ! phase2_validate_team "$t"; then
    phase2_warn "Saved team is invalid or blocked."
    return 1
  fi

  local out_dir notes_dir out_csv
  out_dir="$(phase2__resolve_out_dir 2>/dev/null || true)"
  notes_dir="${out_dir}/${OUT_SUBDIR_NOTES:-notes}"
  mkdir -p "$notes_dir" 2>/dev/null || true
  out_csv="${notes_dir}/phase2_targets_from_phase1.csv"

  phase2_section "Import Phase 1 Intel"
  phase2_intel__import_targets "$t" "$out_csv" || return 1
  phase2_log "[*] Wrote: $out_csv"
  return 0
}

phase2_main__menu() {
  while true; do
    phase2_menu__header "${PHASE_NAME} v${PHASE_VERSION}" "Privilege Expansion - Main Menu"

    local last_team
    last_team="$(phase2_load_last_team 2>/dev/null || true)"
    if [[ -n "$last_team" ]]; then
      if ! phase2_validate_team "$last_team"; then
        phase2_warn "Saved team is invalid or blocked; choose a team via phase2_operator.sh."
        last_team=""
      fi
    fi
    [[ -n "$last_team" ]] && phase2_menu__print_kv "Team" "$last_team"
    [[ -n "$last_team" ]] && ccdc_net__warn_if_team_out_of_range "$last_team" || true
    [[ -n "$last_team" ]] && phase2_menu__print_kv "Mapping" "$(ccdc_net__mapping_source)"
    phase2_menu__print_kv "Output dir" "$(phase2__resolve_out_dir 2>/dev/null || echo unknown)"

      phase2_menu__divider
      local idx
      idx="$(
        phase2_menu__choose "Select an action" 1 \
          "Show Phase 2 paths + status" \
          "Self-check (tools + dirs + ledger)" \
          "Targets: team/subnet summary + candidates (phase2_targets.sh)" \
          "Creds: add/list/update ledger (phase2_creds_ops.sh)" \
          "Remote/PrivEsc: SSH proof + triage (phase2_remote_privesc.sh)" \
          "Quick: Local PrivEsc triage now (this host)" \
          "Intel: Phase 1 summary (this team)" \
          "Intel: Import Phase 1 targets -> Phase 2 notes" \
          "Open cred ledger (view)" \
          "Ops ledger: add action row (ops_ledger.csv)" \
          "Exit"
      )"

    case "$idx" in
      0|11)
        phase2_log "[*] Exiting Phase 2 main."
        return 0
        ;;
      1)
        phase2_main__show_paths
        phase2_menu__pause
        ;;
      2)
        phase2_main__self_check
        phase2_menu__pause
        ;;
      3)
        if phase2_main__have_script "$SCRIPT_TARGETS"; then
          phase2_main__run_script "$SCRIPT_TARGETS" || true
        else
          phase2_warn "phase2_targets.sh not found yet."
        fi
        phase2_menu__pause
        ;;
      4)
        if phase2_main__have_script "$SCRIPT_CREDS"; then
          phase2_main__run_script "$SCRIPT_CREDS" || true
        else
          phase2_warn "phase2_creds_ops.sh not found yet."
        fi
        phase2_menu__pause
        ;;
      5)
        if phase2_main__have_script "$SCRIPT_REMOTE"; then
          phase2_main__run_script "$SCRIPT_REMOTE" || true
        else
          phase2_warn "phase2_remote_privesc.sh not found yet."
        fi
        phase2_menu__pause
        ;;
      6)
        phase2_section "Local PrivEsc Triage"
        # Tag with hostname for clarity
        local tag
        tag="$(hostname 2>/dev/null || echo local)"
        local enum_file
        enum_file="$(phase2_privesc_linux_enum_local --tag "$tag" 2>/dev/null || true)"
        if [[ -n "$enum_file" && -f "$enum_file" ]]; then
          phase2_log "[*] Enum saved: $enum_file"
          phase2_privesc_linux_quick_hits "$enum_file" || true
        else
          phase2_warn "PrivEsc enum did not produce a file."
        fi
        phase2_menu__pause
        ;;
      7)
        phase2_main__intel_summary || true
        phase2_menu__pause
        ;;
      8)
        phase2_main__intel_import || true
        phase2_menu__pause
        ;;
      9)
        # Open cred ledger using runtime viewer
        local csv
        csv="$(phase2_creds__csv_path 2>/dev/null || true)"
        if [[ -n "$csv" && -f "$csv" ]]; then
          phase2_open_viewer "$csv" || true
        else
          phase2_warn "cred_ledger.csv not found yet. Run creds init/add first."
        fi
        phase2_menu__pause
        ;;
      10)
        if [[ -x "${PHASE_DIR}/../Scripts/ops_ledger_add.sh" ]]; then
          "${PHASE_DIR}/../Scripts/ops_ledger_add.sh" || true
        else
          phase2_warn "ops_ledger_add.sh not found or not executable."
        fi
        phase2_menu__pause
        ;;
      *)
        echo "Invalid selection."
        ;;
    esac
  done
}

main() {
  phase2_init_run "phase2_privilege_main" || {
    echo "ERROR: failed to init Phase 2 runtime" >&2
    exit 1
  }

  # Ensure base dirs exist early
  phase2_init_env || true

  # Start menu
  phase2_main__menu
}

main "$@"
