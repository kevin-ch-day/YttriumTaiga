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
APPROVALS=""
PHASE1_DIR=""
PHASE2_DIR=""

init_outputs() {
  FOOTHOLDS="${CCDC_OUT_DIR}/footholds.jsonl"
  REENTRY="${CCDC_OUT_DIR}/reentry.md"
  RULES="${CCDC_OUT_DIR}/rules_safety.md"
  APPROVALS="${SCRIPT_DIR}/approved_actions.md"
  PHASE1_DIR="${SCRIPT_DIR}/../Phase01_Recon"
  PHASE2_DIR="${SCRIPT_DIR}/../Phase02_Privilege_Exp"

  # Ensure output dir is writable
  local testfile="${CCDC_OUT_DIR}/.phase3_write_test"
  if ! (echo "test" > "$testfile" 2>/dev/null); then
    ccdc__die "Output directory is not writable: ${CCDC_OUT_DIR}"
    return 1
  fi
  rm -f "$testfile" 2>/dev/null || true

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

Intent:
- Recoverable persistence + continuity only
- Actions are reversible and documented

Approved actions (captain):
- See approved_actions.md (Phase03_Persistence/approved_actions.md) or CAPTAIN_APPROVED=1

Disallowed actions:
- No irreversible persistence
- No OS-level tampering unless explicitly approved
- No service disruption
- No new accounts
- No auth config changes
- No SSH key changes
- No startup/service/cron modifications

Stop conditions:
- If action cannot be explained in one sentence to captain, STOP
- If rules are unclear, STOP and ask
- If action alters auth, startup, or service availability, STOP

EOF
  fi
}

require_captain_approval() {
  if [[ "${CAPTAIN_APPROVED:-0}" == "1" ]]; then
    return 0
  fi

  if [[ -f "$APPROVALS" ]]; then
    return 0
  fi

  if [[ ! -f "$APPROVALS" ]]; then
    if [[ -t 0 ]]; then
      ccdc__section "Captain Approval Record"
      local initials category ts
      initials="$(ccdc_menu__ask "Captain initials" "")"
      category="$(ccdc_menu__ask "Approved action category" "recoverable persistence only")"
      ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
      if [[ -n "$initials" ]]; then
        {
          echo "time=${ts} | initials=${initials} | category=${category}"
        } >> "$APPROVALS"
        ccdc__log "[*] Recorded approval: $APPROVALS"
      else
        ccdc__warn "Missing captain initials. Approval not recorded."
        return 1
      fi
    else
      ccdc__warn "Approval file missing and no TTY to create it: $APPROVALS"
      return 1
    fi
  fi

  return 0
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
  local target service identity access_type stability notes obtained sensitive persistence survives_reboot recovery
  target="$(ccdc_menu__ask "Target host (IP/hostname)" "")"
  service="$(ccdc_menu__ask "Service accessed (ssh/web/admin/api)" "")"
  identity="$(ccdc_menu__ask "Identity (user/role)" "")"
  access_type="$(ccdc_menu__ask "Access type (ui/shell/token/api)" "")"
  stability="$(ccdc_menu__ask "Stability (stable/semi-stable/fragile/unknown)" "unknown")"
  stability="${stability,,}"
  case "$stability" in
    stable|semi-stable|fragile|unknown) ;;
    *) ccdc__warn "Invalid stability. Use stable/semi-stable/fragile/unknown."; return 1 ;;
  esac
  sensitive="$(ccdc_menu__ask "Sensitive service? (ad/mail/identity/db) [y/N]" "N")"
  sensitive="${sensitive,,}"
  [[ "$sensitive" == "y" || "$sensitive" == "yes" ]] && sensitive="true" || sensitive="false"
  persistence="$(ccdc_menu__ask "Persistence method (high-level)" "none")"
  survives_reboot="$(ccdc_menu__ask "Survives reboot? (yes/no)" "no")"
  survives_reboot="${survives_reboot,,}"
  [[ "$survives_reboot" == "y" || "$survives_reboot" == "yes" ]] && survives_reboot="true" || survives_reboot="false"
  recovery="$(ccdc_menu__ask "How to remove / recover" "")"
  obtained="$(ccdc_menu__ask "How obtained (ph1/ph2/manual)" "manual")"
  notes="$(ccdc_menu__ask "Notes / next steps" "")"

  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"

  printf '{\"time\":\"%s\",\"target\":\"%s\",\"service\":\"%s\",\"identity\":\"%s\",\"access_type\":\"%s\",\"stability\":\"%s\",\"obtained\":\"%s\",\"persistence_method\":\"%s\",\"survives_reboot\":%s,\"recovery\":\"%s\",\"sensitive_service\":%s,\"notes\":\"%s\"}\n' \
    "$(json_escape "$ts")" \
    "$(json_escape "$target")" \
    "$(json_escape "$service")" \
    "$(json_escape "$identity")" \
    "$(json_escape "$access_type")" \
    "$(json_escape "$stability")" \
    "$(json_escape "$obtained")" \
    "$(json_escape "$persistence")" \
    "$survives_reboot" \
    "$(json_escape "$recovery")" \
    "$sensitive" \
    "$(json_escape "$notes")" \
    >> "$FOOTHOLDS"

  ccdc__log "[*] Added foothold: $target ($service) -> $FOOTHOLDS"
}

add_reentry_plan() {
  require_captain_approval || return 1

  ccdc__section "Add Re-entry Checklist"
  local target primary alt1 alt2 creds_fail host_missing notes sensitive recovery logs_notice not_try
  target="$(ccdc_menu__ask "Target host (IP/hostname)" "")"
  primary="$(ccdc_menu__ask "Primary re-entry path" "")"
  alt1="$(ccdc_menu__ask "Alternate path A" "")"
  alt2="$(ccdc_menu__ask "Alternate path B" "")"
  creds_fail="$(ccdc_menu__ask "If creds fail, do this" "")"
  host_missing="$(ccdc_menu__ask "If host disappears, do this" "")"
  sensitive="$(ccdc_menu__ask "Sensitive service? (ad/mail/identity/db) [y/N]" "N")"
  sensitive="${sensitive,,}"
  recovery="$(ccdc_menu__ask "Defender recovery/removal steps" "")"
  logs_notice="$(ccdc_menu__ask "Logs/alerts that should fire" "")"
  not_try="$(ccdc_menu__ask "What NOT to try (rules reminder)" "")"
  notes="$(ccdc_menu__ask "Notes" "")"

  {
    echo ""
    echo "## Re-entry: ${target}"
    echo "- Primary: ${primary}"
    echo "- Alternate A: ${alt1}"
    echo "- Alternate B: ${alt2}"
    echo "- If creds fail: ${creds_fail}"
    echo "- If host missing: ${host_missing}"
    [[ -n "$recovery" ]] && echo "- Defender recovery: ${recovery}"
    [[ -n "$logs_notice" ]] && echo "- Expected logs/alerts: ${logs_notice}"
    [[ -n "$not_try" ]] && echo "- Do NOT try: ${not_try}"
    if [[ "$sensitive" == "y" || "$sensitive" == "yes" ]]; then
      echo "- Caution: sensitive service; do not escalate without captain approval"
    fi
    [[ -n "$notes" ]] && echo "- Notes: ${notes}"
    echo "- Rules reminder: no irreversible changes"
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

summary_view() {
  ccdc__section "Phase 3 Summary (quick)"

  local total stable semi fragile unknown
  total="$(wc -l < "$FOOTHOLDS" 2>/dev/null || echo 0)"
  stable="$(grep -c '"stability":"stable"' "$FOOTHOLDS" 2>/dev/null || echo 0)"
  semi="$(grep -c '"stability":"semi-stable"' "$FOOTHOLDS" 2>/dev/null || echo 0)"
  fragile="$(grep -c '"stability":"fragile"' "$FOOTHOLDS" 2>/dev/null || echo 0)"
  unknown="$(grep -c '"stability":"unknown"' "$FOOTHOLDS" 2>/dev/null || echo 0)"

  ccdc__log_kv "Footholds total" "$total"
  ccdc__log_kv "Stable" "$stable"
  ccdc__log_kv "Semi-stable" "$semi"
  ccdc__log_kv "Fragile" "$fragile"
  ccdc__log_kv "Unknown" "$unknown"

  ccdc__log ""
  ccdc__log "Top targets (first 10):"
  awk -F'"target":"' 'NF>1 {split($2,a,"\""); print a[1]}' "$FOOTHOLDS" 2>/dev/null \
    | sort | uniq -c | sort -nr | head -n 10 \
    | sed 's/^/  /' || true
}

auto_import_footholds() {
  require_captain_approval || return 1
  ccdc__section "Auto-Import Footholds (from Phase 1/2)"

  local count=0
  local svc_csv="${PHASE1_DIR}/output/services.csv"
  local web_csv="${PHASE1_DIR}/output/web_fingerprint.csv"
  local creds_csv="${PHASE2_DIR}/output/loot/cred_ledger.csv"

  if [[ -f "$svc_csv" ]]; then
    ccdc__log "[*] Importing from: $svc_csv"
    awk -F',' 'NR>1 {print $1","$2","$3","$5}' "$svc_csv" 2>/dev/null | head -n 50 | while IFS=',' read -r ip scheme port server; do
      [[ -n "$ip" ]] || continue
      printf '{\"time\":\"%s\",\"target\":\"%s\",\"service\":\"%s\",\"identity\":\"%s\",\"access_type\":\"%s\",\"stability\":\"%s\",\"obtained\":\"%s\",\"persistence_method\":\"%s\",\"survives_reboot\":%s,\"recovery\":\"%s\",\"sensitive_service\":%s,\"notes\":\"%s\"}\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)" \
        "$ip" \
        "${scheme}:${port}" \
        "" \
        "web" \
        "unknown" \
        "ph1_service_inventory" \
        "none" \
        "false" \
        "" \
        "false" \
        "server=${server}" \
        >> "$FOOTHOLDS"
      count=$((count+1))
    done
  fi

  if [[ -f "$web_csv" ]]; then
    ccdc__log "[*] Importing from: $web_csv"
    awk -F',' 'NR>1 {print $1","$2","$3","$4","$6}' "$web_csv" 2>/dev/null | head -n 50 | while IFS=',' read -r ip scheme port path title; do
      [[ -n "$ip" ]] || continue
      printf '{\"time\":\"%s\",\"target\":\"%s\",\"service\":\"%s\",\"identity\":\"%s\",\"access_type\":\"%s\",\"stability\":\"%s\",\"obtained\":\"%s\",\"persistence_method\":\"%s\",\"survives_reboot\":%s,\"recovery\":\"%s\",\"sensitive_service\":%s,\"notes\":\"%s\"}\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)" \
        "$ip" \
        "${scheme}:${port}${path}" \
        "" \
        "web" \
        "unknown" \
        "ph1_web_fingerprint" \
        "none" \
        "false" \
        "" \
        "false" \
        "title=${title}" \
        >> "$FOOTHOLDS"
      count=$((count+1))
    done
  fi

  if [[ -f "$creds_csv" ]]; then
    ccdc__log "[*] Importing from: $creds_csv"
    awk -F',' 'NR>1 {print $4","$6","$8}' "$creds_csv" 2>/dev/null | head -n 50 | while IFS=',' read -r user target status; do
      [[ -n "$target" ]] || continue
      printf '{\"time\":\"%s\",\"target\":\"%s\",\"service\":\"%s\",\"identity\":\"%s\",\"access_type\":\"%s\",\"stability\":\"%s\",\"obtained\":\"%s\",\"persistence_method\":\"%s\",\"survives_reboot\":%s,\"recovery\":\"%s\",\"sensitive_service\":%s,\"notes\":\"%s\"}\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)" \
        "$target" \
        "credential" \
        "$user" \
        "auth" \
        "unknown" \
        "ph2_cred_ledger" \
        "none" \
        "false" \
        "" \
        "false" \
        "status=${status}" \
        >> "$FOOTHOLDS"
      count=$((count+1))
    done
  fi

  ccdc__log "[*] Imported entries: ${count}"
}

generate_reentry_from_ledger() {
  require_captain_approval || return 1
  ccdc__section "Generate Re-entry Checklists (from ledger)"

  if [[ ! -s "$FOOTHOLDS" ]]; then
    ccdc__warn "No footholds found to generate from."
    return 1
  fi

  {
    echo ""
    echo "# Auto-generated Re-entry Sections ($(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date))"
  } >> "$REENTRY"

  awk -F'"' '/\"target\":/ {for(i=1;i<=NF;i++){if($i=="target"){t=$(i+2)} if($i=="service"){s=$(i+2)} if($i=="identity"){u=$(i+2)} if($i=="stability"){st=$(i+2)} if($i=="sensitive_service"){ss=$(i+2)}} if(t!=""){print t"\t"s"\t"u"\t"st"\t"ss}}' "$FOOTHOLDS" \
    | sort -u | while IFS=$'\t' read -r t s u st ss; do
      {
        echo ""
        echo "## Re-entry: ${t}"
        [[ -n "$s" ]] && echo "- Service: ${s}"
        [[ -n "$u" ]] && echo "- Identity: ${u}"
        [[ -n "$st" ]] && echo "- Stability: ${st}"
        echo "- Primary: (fill)"
        echo "- Alternate A: (fill)"
        echo "- If creds fail: (fill)"
        echo "- Defender recovery: (fill)"
        echo "- Expected logs/alerts: (fill)"
        if [[ "$ss" == "true" ]]; then
          echo "- Caution: sensitive service; do not escalate without captain approval"
        fi
        echo "- Rules reminder: no irreversible changes"
      } >> "$REENTRY"
    done

  ccdc__log "[*] Generated re-entry sections from ledger."
}

recovery_summary() {
  ccdc__section "Recovery Summary (from ledger)"
  awk -F'"' '
    /\"target\":/ {
      for(i=1;i<=NF;i++){
        if($i=="target"){t=$(i+2)}
        if($i=="recovery"){r=$(i+2)}
      }
      if(t!="" || r!=""){print t" :: "r}
      t=""; r=""
    }
  ' "$FOOTHOLDS" 2>/dev/null | sed 's/^/  /' || true
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
      "Summary view (quick)" \
      "Auto-import footholds (Phase 1/2)" \
      "Generate re-entry from ledger" \
      "Recovery summary (from ledger)" \
      "View outputs" \
      "Exit")"

    case "$choice" in
      1) add_foothold; ccdc_menu__pause ;;
      2) add_reentry_plan; ccdc_menu__pause ;;
      3) summary_view; ccdc_menu__pause ;;
      4) auto_import_footholds; ccdc_menu__pause ;;
      5) generate_reentry_from_ledger; ccdc_menu__pause ;;
      6) recovery_summary; ccdc_menu__pause ;;
      7) view_files_menu ;;
      0|8) return 0 ;;
    esac
  done
}

main() {
  ccdc__init_run "phase3_continuity" || exit 1
  ccdc__require_cmds date cat printf awk sort uniq head wc || true
  init_outputs

  if ccdc_menu__is_interactive; then
    menu_loop
  else
    ccdc__log "Non-interactive mode. Use CAPTAIN_APPROVED=1 and run with TTY for prompts."
  fi
}

main "$@"
