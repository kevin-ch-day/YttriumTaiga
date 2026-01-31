#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase3_continuity.sh
# Purpose : Phase 3 - Access Continuity (Persistence-lite)
# Version : 0.1.0
#
# Outputs (Phase 3 dirs):
#   ./logs/phase3_continuity.log
#   ./output/footholds.jsonl
#   ./output/reentry.md
#   ./output/rules_safety.md
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Import libs ----
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_runtime.sh" || { echo "ERROR: Missing lib/ccdc_runtime.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_utils.sh"   || { echo "ERROR: Missing lib/ccdc_utils.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_menu.sh"    || { echo "ERROR: Missing lib/ccdc_menu.sh"; exit 3; }

FOOTHOLDS=""
REENTRY=""
RULES=""

init_outputs() {
  FOOTHOLDS="${CCDC_OUT_DIR}/footholds.jsonl"
  REENTRY="${CCDC_OUT_DIR}/reentry.md"
  RULES="${CCDC_OUT_DIR}/rules_safety.md"

  [[ -f "$FOOTHOLDS" ]] || : > "$FOOTHOLDS"

  if [[ ! -f "$REENTRY" ]]; then
    cat >"$REENTRY" <<'EOF'
# Phase 03 - Re-entry Checklists

Use this to record re-entry paths per foothold.

EOF
  fi

  if [[ ! -f "$RULES" ]]; then
    cat >"$RULES" <<'EOF'
# Phase 03 - Rules / Safety Record

Approved actions (captain-signed):
- (fill in)

Disallowed actions:
- No irreversible persistence
- No OS-level tampering unless explicitly approved
- No service disruption

Stop conditions:
- If action cannot be explained in one sentence to captain, STOP
- If rules are unclear, STOP and ask

EOF
  fi
}

require_captain_approval() {
  if [[ "${CAPTAIN_APPROVED:-0}" == "1" ]]; then
    return 0
  fi
  if [[ -t 0 ]]; then
    read -r -p "Captain approval required. Type CAPTAIN to proceed: " ans || ans=""
    [[ "$ans" == "CAPTAIN" ]] && return 0
  fi
  ccdc__warn "Captain approval not granted. Set CAPTAIN_APPROVED=1 or provide CAPTAIN in prompt."
  return 1
}

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  echo "$s"
}

add_foothold() {
  require_captain_approval || return 1

  ccdc__section "Add Foothold (Session Ledger)"
  local target service identity access_type stability notes obtained
  target="$(ccdc_menu__ask "Target host (IP/hostname)" "")"
  service="$(ccdc_menu__ask "Service accessed (ssh/web/admin/api)" "")"
  identity="$(ccdc_menu__ask "Identity (user/role)" "")"
  access_type="$(ccdc_menu__ask "Access type (ui/shell/token/api)" "")"
  stability="$(ccdc_menu__ask "Stability (stable/fragile/unknown)" "unknown")"
  obtained="$(ccdc_menu__ask "How obtained (ph1/ph2/manual)" "manual")"
  notes="$(ccdc_menu__ask "Notes / next steps" "")"

  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"

  printf '{\"time\":\"%s\",\"target\":\"%s\",\"service\":\"%s\",\"identity\":\"%s\",\"access_type\":\"%s\",\"stability\":\"%s\",\"obtained\":\"%s\",\"notes\":\"%s\"}\n' \
    "$(json_escape "$ts")" \
    "$(json_escape "$target")" \
    "$(json_escape "$service")" \
    "$(json_escape "$identity")" \
    "$(json_escape "$access_type")" \
    "$(json_escape "$stability")" \
    "$(json_escape "$obtained")" \
    "$(json_escape "$notes")" \
    >> "$FOOTHOLDS"

  ccdc__log "[*] Added foothold: $target ($service) -> $FOOTHOLDS"
}

add_reentry_plan() {
  require_captain_approval || return 1

  ccdc__section "Add Re-entry Checklist"
  local target primary alt1 alt2 creds_fail host_missing notes
  target="$(ccdc_menu__ask "Target host (IP/hostname)" "")"
  primary="$(ccdc_menu__ask "Primary re-entry path" "")"
  alt1="$(ccdc_menu__ask "Alternate path A" "")"
  alt2="$(ccdc_menu__ask "Alternate path B" "")"
  creds_fail="$(ccdc_menu__ask "If creds fail, do this" "")"
  host_missing="$(ccdc_menu__ask "If host disappears, do this" "")"
  notes="$(ccdc_menu__ask "Notes" "")"

  {
    echo ""
    echo "## Re-entry: ${target}"
    echo "- Primary: ${primary}"
    echo "- Alternate A: ${alt1}"
    echo "- Alternate B: ${alt2}"
    echo "- If creds fail: ${creds_fail}"
    echo "- If host missing: ${host_missing}"
    [[ -n "$notes" ]] && echo "- Notes: ${notes}"
  } >> "$REENTRY"

  ccdc__log "[*] Added re-entry checklist: $target -> $REENTRY"
}

view_files_menu() {
  local choice file
  while true; do
    ccdc_menu__header "Phase 3 - View Outputs" "Choose a file to view"
    choice="$(ccdc_menu__choose "Select output" 1 \
      "footholds.jsonl" \
      "reentry.md" \
      "rules_safety.md" \
      "Back")"
    case "$choice" in
      1) file="$FOOTHOLDS" ;;
      2) file="$REENTRY" ;;
      3) file="$RULES" ;;
      0|4) return 0 ;;
    esac
    ccdc__open_viewer "$file" || true
    ccdc_menu__pause
  done
}

menu_loop() {
  while true; do
    ccdc_menu__header "Phase 3 - Continuity" "Persistence-lite (safe, reversible)"
    ccdc__log_kv "Footholds" "$FOOTHOLDS"
    ccdc__log_kv "Re-entry" "$REENTRY"
    ccdc__log_kv "Rules" "$RULES"
    echo ""

    local choice
    choice="$(ccdc_menu__choose "Select action" 1 \
      "Add foothold entry" \
      "Add re-entry checklist" \
      "View outputs" \
      "Exit")"

    case "$choice" in
      1) add_foothold; ccdc_menu__pause ;;
      2) add_reentry_plan; ccdc_menu__pause ;;
      3) view_files_menu ;;
      0|4) return 0 ;;
    esac
  done
}

main() {
  ccdc__init_run "phase3_continuity" || exit 1
  init_outputs

  if ccdc_menu__is_interactive; then
    menu_loop
  else
    ccdc__log "Non-interactive mode. Use CAPTAIN_APPROVED=1 and run with TTY for prompts."
  fi
}

main "$@"
