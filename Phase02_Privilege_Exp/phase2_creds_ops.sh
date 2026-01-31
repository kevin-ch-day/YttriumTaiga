#!/usr/bin/env bash
# phase2_creds_ops.sh
set -euo pipefail

# ============================================================
# Phase 2 (Privilege Expansion) - Credential Ops
# Version : 0.1.0
#
# Purpose:
# - Menu-driven credential ledger operations for Phase 2
# - Add / list / update status / filter-by-target
#
# Run:
#   chmod +x ./phase2_creds_ops.sh
#   ./phase2_creds_ops.sh
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
source "${LIB_DIR}/phase2_lib_creds.sh"

phase2_creds_ops__prompt_add() {
  phase2_section "Add Credential (Ledger Entry)"

  local type user secret target source notes status

  type="$(phase2_menu__ask "Type (password|hash|key|token|api_key|other)" "password")"
  user="$(phase2_menu__ask "Username (or blank)" "")"
  secret="$(phase2_menu__ask "Secret (will be stored in CSV; masked in MD)" "")"
  target="$(phase2_menu__ask "Target (ip:port or hostname/service)" "")"
  source="$(phase2_menu__ask "Source (file:/path | cmd:... | manual | dump:...)" "manual")"
  notes="$(phase2_menu__ask "Notes" "")"
  status="$(phase2_menu__ask "Status (untested|valid|invalid)" "untested")"

  if [[ -z "$type" ]]; then
    phase2_warn "Type is required."
    return 1
  fi

  # Add and echo ID
  local cid
  cid="$(phase2_creds_add "$type" "$user" "$secret" "$target" "$source" "$notes" "$status")" || return 1
  phase2_log "[*] Added cred id: $cid"
  return 0
}

phase2_creds_ops__prompt_status() {
  phase2_section "Update Credential Status"

  local cid new_status notes
  cid="$(phase2_menu__ask "Credential ID (from ledger)" "")"
  [[ -n "$cid" ]] || { phase2_warn "ID is required."; return 1; }

  new_status="$(phase2_menu__ask "New status (valid|invalid|untested)" "valid")"
  notes="$(phase2_menu__ask "Add notes (optional; appended)" "")"

  phase2_creds_set_status "$cid" "$new_status" "$notes" || return 1
  phase2_log "[*] Updated: $cid -> $new_status"
  return 0
}

phase2_creds_ops__list_masked() {
  phase2_section "Credential Ledger (masked view)"
  phase2_creds_list || true
  return 0
}

phase2_creds_ops__list_full() {
  phase2_section "Credential Ledger (FULL / includes secrets)"
  phase2_warn "FULL view includes secrets. Do not paste into shared chat/logs."
  if ! phase2_menu__confirm "Show FULL ledger nowNO" "N"; then
    return 0
  fi
  phase2_creds_list --full || true
  return 0
}

phase2_creds_ops__filter_target() {
  phase2_section "Filter Credentials by Target"
  local token
  token="$(phase2_menu__ask "Enter target token (e.g., 172.25.21.10 or :22)" "")"
  [[ -n "$token" ]] || { phase2_warn "Token required."; return 1; }

  phase2_log "[*] Matching rows (CSV lines):"
  phase2_creds_best_for_target "$token" || {
    phase2_warn "No matches (or ledger missing)."
    return 1
  }
  return 0
}

phase2_creds_ops__open_ledger() {
  local csv md
  csv="$(phase2_creds__csv_path 2>/dev/null || true)"
  md="$(phase2_creds__md_path 2>/dev/null || true)"

  phase2_section "Open Ledger Files"
  if [[ -n "$md" && -f "$md" ]]; then
    phase2_log "[*] MD:  $md"
  fi
  if [[ -n "$csv" && -f "$csv" ]]; then
    phase2_log "[*] CSV: $csv"
  fi

  local which
  which="$(phase2_menu__choose "Open which fileNO" 1 "Markdown (no secrets)" "CSV (contains secrets)" "Cancel")"
  case "$which" in
    1) [[ -n "$md" ]] && phase2_open_viewer "$md" || phase2_warn "MD not found";;
    2)
      phase2_warn "CSV contains secrets."
      if phase2_menu__confirm "Open CSV anywayNO" "N"; then
        [[ -n "$csv" ]] && phase2_open_viewer "$csv" || phase2_warn "CSV not found"
      fi
      ;;
    *) return 0 ;;
  esac
  return 0
}

main_menu() {
  phase2_creds_init || true

  while true; do
    phase2_menu__header "${PHASE_NAME} v${PHASE_VERSION}" "Credential Ops"

    local idx
    idx="$(
      phase2_menu__choose "Select an action" 1 \
        "Add credential" \
        "List ledger (masked)" \
        "List ledger (FULL / secrets)" \
        "Update status by ID" \
        "Filter by target token" \
        "Open ledger file (MD/CSV)" \
        "Back / Exit"
    )"

    case "$idx" in
      0|7) return 0 ;;
      1) phase2_creds_ops__prompt_add || true; phase2_menu__pause ;;
      2) phase2_creds_ops__list_masked || true; phase2_menu__pause ;;
      3) phase2_creds_ops__list_full || true; phase2_menu__pause ;;
      4) phase2_creds_ops__prompt_status || true; phase2_menu__pause ;;
      5) phase2_creds_ops__filter_target || true; phase2_menu__pause ;;
      6) phase2_creds_ops__open_ledger || true; phase2_menu__pause ;;
      *) echo "Invalid selection."; phase2_menu__pause ;;
    esac
  done
}

main() {
  phase2_init_run "phase2_creds_ops" || {
    echo "ERROR: failed to init Phase 2 runtime" >&2
    exit 1
  }
  main_menu
}

main "$@"
