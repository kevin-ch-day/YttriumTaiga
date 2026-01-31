#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_network_monitoring.sh
# Purpose : Phase 1 - Red Team Network Monitoring + Health Check (read-only)
# Version : 0.3.0
#
# Usage:
#   ./phase1_network_monitoring.sh
#   ./phase1_network_monitoring.sh <TEAM_NUMBER>
#
# Output:
#   ./logs/phase1_network_monitoring.log
#   ./output/network_monitoring.summary.txt
#   ./output/network_monitoring.quick.txt
#
# Notes:
# - Read-only: posture + health + sanity checks (no scans).
# - Uses Phase 1 libs for consistent UX/logging.
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
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_error.sh" || true

TEAM=""
OUT_SUMMARY=""
OUT_QUICK=""

usage() { ccdc__usage_team "$(basename "$0")"; }

init_outputs() {
  OUT_SUMMARY="${CCDC_OUT_DIR}/network_monitoring.summary.txt"
  OUT_QUICK="${CCDC_OUT_DIR}/network_monitoring.quick.txt"
  : > "$OUT_SUMMARY"
  : > "$OUT_QUICK"
}

append() { echo "$*" >> "$OUT_SUMMARY"; }
quick()  { echo "$*" >> "$OUT_QUICK"; }

# ---------- small helpers ----------
default_route_line() { ip route show default 2>/dev/null | head -n 1 || true; }
default_gw() { default_route_line | awk '{for(i=1;i<=NF;i++) if($i=="via") print $(i+1)}' | head -n 1 || true; }
default_if() { default_route_line | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n 1 || true; }

ping_once() {
  local host="$1"
  command -v ping >/dev/null 2>&1 || return 1
  ping -c 1 -W 1 "$host" >/dev/null 2>&1
}

dns_test() {
  # returns 0 if DNS resolves example.com using available tool
  if command -v dig >/dev/null 2>&1; then
    dig +time=2 +tries=1 example.com A >/dev/null 2>&1
    return $?
  elif command -v nslookup >/dev/null 2>&1; then
    nslookup example.com >/dev/null 2>&1
    return $?
  elif command -v host >/dev/null 2>&1; then
    host example.com >/dev/null 2>&1
    return $?
  fi
  return 2
}

write_team_context() {
  if [[ -n "$TEAM" ]]; then
    append "== Team Network Context =="
    append "Team: $TEAM"
    append "Public subnet: $(ccdc__target_net "$TEAM" 2>/dev/null || echo unknown)"
    append "Core transit: $(ccdc_net__core_transit_cidr "$TEAM" 2>/dev/null || echo unknown)"
    append "Core router:  $(ccdc_net__core_transit_router_ip "$TEAM" 2>/dev/null || echo unknown)"
    append "Team transit: $(ccdc_net__core_transit_team_ip "$TEAM" 2>/dev/null || echo unknown)"
    append ""
    append "Red Team Focus (Phase 1):"
    append "  OK Primary surface: 172.25.<team_octet>.0/24 (scoring/public)"
    append "  WARN Observe only:    172.31.<team_octet>.0/29 (transit plumbing)"
    append "  NO Not your focus:  172.20.x.x (internal LAN behind firewalls)"
    append ""
  fi
}

write_quick_block() {
  quick "CCDC Phase 1 -- Network Quick Check"
  quick "Time: $(ccdc__now)"
  quick "Host: $(hostname 2>/dev/null || echo unknown)"
  quick "User: $(whoami 2>/dev/null || echo unknown)"
  quick ""

  local dr gw iface
  dr="$(default_route_line)"
  gw="$(default_gw)"
  iface="$(default_if)"
  quick "Default route: ${dr:-none}"
  quick "Gateway:       ${gw:-unknown}"
  quick "Iface:         ${iface:-unknown}"

  if [[ -n "$TEAM" ]]; then
    quick "Team:          $TEAM"
    quick "Public subnet: $(ccdc__target_net "$TEAM" 2>/dev/null || echo unknown)"
  else
    quick "Team:          (not set)"
  fi
  quick ""
}

run_quick_checks() {
  ccdc__section "Quick checks"
  init_outputs

  TEAM="$(ccdc__parse_team_or_last "$TEAM_ARG")" || TEAM=""

  write_quick_block
  append "Network Monitoring + Health Check"
  append "Time: $(ccdc__now)"
  append "Host: $(hostname 2>/dev/null || echo unknown)"
  append "User: $(whoami 2>/dev/null || echo unknown)"
  append ""
  write_team_context

  local gw
  gw="$(default_gw)"
  append "== Connectivity =="
  if [[ -n "$gw" ]]; then
    if ping_once "$gw"; then
      append "Ping gateway ($gw): OK"
      quick "Ping gateway:  OK ($gw)"
    else
      append "Ping gateway ($gw): FAIL"
      quick "Ping gateway:  FAIL ($gw)"
    fi
  else
    append "Ping gateway: skipped (no default gateway found)"
    quick "Ping gateway:  skipped (no GW)"
  fi

  local dns_status="unknown"
  if dns_test; then
    dns_status="OK"
  else
    rc=$NO
    if [[ "$rc" -eq 2 ]]; then dns_status="SKIP (no tool)"; else dns_status="FAIL"; fi
  fi
  append "DNS resolve example.com: $dns_status"
  quick "DNS:           $dns_status"

  # Optional: sanity ping one candidate in your public subnet (very light)
  if [[ -n "$TEAM" ]]; then
    local test_ip
    test_ip="$(ccdc_net__public_host "$TEAM" 1 2>/dev/null || true)"
    if [[ -n "$test_ip" ]]; then
      if ping_once "$test_ip"; then
        append "Ping sample public host ($test_ip): OK (may just be routing)"
        quick "Ping public(.1): OK ($test_ip)"
      else
        append "Ping sample public host ($test_ip): FAIL (not unusual if ICMP blocked)"
        quick "Ping public(.1): FAIL/blocked ($test_ip)"
      fi
    fi
  fi

  append ""
  ccdc__log "[*] Wrote quick:  $OUT_QUICK"
  ccdc__log "[*] Wrote report: $OUT_SUMMARY"
}

run_full_checks() {
  run_quick_checks

  ccdc__section "Full checks"

  append "== Interfaces (ip -br a) =="
  if command -v ip >/dev/null 2>&1; then
    ip -br a >> "$OUT_SUMMARY" 2>/dev/null || true
  else
    append "ip command not found."
  fi
  append ""

  append "== Routes =="
  if command -v ip >/dev/null 2>&1; then
    ip route >> "$OUT_SUMMARY" 2>/dev/null || true
  fi
  append ""

  append "== resolv.conf =="
  if [[ -f /etc/resolv.conf ]]; then
    cat /etc/resolv.conf >> "$OUT_SUMMARY" 2>/dev/null || true
  else
    append "/etc/resolv.conf missing"
  fi
  append ""

  append "== Listening sockets (ss/netstat) =="
  if command -v ss >/dev/null 2>&1; then
    ss -lntup >> "$OUT_SUMMARY" 2>/dev/null || true
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tulnp >> "$OUT_SUMMARY" 2>/dev/null || true
  else
    append "Neither ss nor netstat is available."
  fi
  append ""

  append "== Listener Summary (common ports) =="
  if command -v ss >/dev/null 2>&1; then
    # show common interesting ports if present
    ss -lntup 2>/dev/null | awk '
      /LISTEN/ && ($5 ~ /:22$|:53$|:80$|:443$|:445$|:3306$|:8080$|:8443$/) {print}
    ' >> "$OUT_SUMMARY" || true
  fi
  append ""

  append "== Firewall (read-only) =="
  if command -v ufw >/dev/null 2>&1; then
    ufw status verbose >> "$OUT_SUMMARY" 2>/dev/null || true
  elif command -v iptables >/dev/null 2>&1; then
    iptables -L -n -v >> "$OUT_SUMMARY" 2>/dev/null || true
  elif command -v nft >/dev/null 2>&1; then
    nft list ruleset >> "$OUT_SUMMARY" 2>/dev/null || true
  else
    append "No ufw/iptables/nft tool detected."
  fi
  append ""

  append "== Resource Snapshot =="
  if command -v uptime >/dev/null 2>&1; then
    append "Uptime/load: $(uptime 2>/dev/null || true)"
  fi
  if command -v free >/dev/null 2>&1; then
    append "Memory: $(free -h | awk '/Mem:/ {print $3 "/" $2}' 2>/dev/null || true)"
  fi
  if command -v df >/dev/null 2>&1; then
    append "Disk(/): $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}' 2>/dev/null || true)"
  fi
  append ""

  append "== Red Team Hygiene (your box) =="
  append "If you see unexpected listeners here, stop and figure out why."
  append "Your Kali should not be running random services during Phase 1."
  append ""

  ccdc__section "Done"
  ccdc__log "[*] Wrote: $OUT_SUMMARY"
  ccdc__log "[*] Wrote: $OUT_QUICK"
}

menu_loop() {
  while true; do
    ccdc_menu__header "Phase 1 -- Network Monitoring" "Red Team posture + health checks (read-only)"
    ccdc__log_kv "Quick" "$OUT_QUICK"
    ccdc__log_kv "Full"  "$OUT_SUMMARY"
    echo ""

    local choice
    choice="$(ccdc_menu__choose "Select action" 1 \
      "Run QUICK checks (fast)" \
      "Run FULL checks (more detail)" \
      "View QUICK output" \
      "View FULL output" \
      "View this script log" \
      "Exit")"

    case "$choice" in
      1) run_quick_checks; ccdc_menu__pause ;;
      2) run_full_checks; ccdc_menu__pause ;;
      3) ccdc__open_viewer "$OUT_QUICK" || true; ccdc_menu__pause ;;
      4) ccdc__open_viewer "$OUT_SUMMARY" || true; ccdc_menu__pause ;;
      5) ccdc__open_viewer "$CCDC_LOG_FILE" || true; ccdc_menu__pause ;;
      0|6) return 0 ;;
    esac
  done
}

main() {
  ccdc__init_run "phase1_network_monitoring" || exit 1

  # Commands used (warn-only; script still runs with best-effort fallbacks)
  if declare -F ccdc_err_require_cmds >/dev/null 2>&1; then
    ccdc_err_require_cmds ip awk sed hostname whoami df free uptime ss ping || true
  else
    ccdc__require_cmds ip awk sed hostname whoami df free uptime ss ping || true
  fi

  # Resolve team if provided or previously saved (optional)
  TEAM=""
  if TEAM_PARSED="$(ccdc__parse_team_or_last "$TEAM_ARG" 2>/dev/null)"; then
    TEAM="$TEAM_PARSED"
  fi

  if ccdc_menu__is_interactive; then
    TEAM="$(ccdc_menu__pick_team "$TEAM" "1")" || return 0
    [[ -n "$TEAM" ]] && ccdc_net__warn_if_team_out_of_range "$TEAM" || true
    [[ -n "$TEAM" ]] && ccdc__log_kv "Mapping" "$(ccdc_net__mapping_source)" || true
    [[ -n "$TEAM" ]] && ccdc__save_last_team "$TEAM" || true
    [[ -n "$TEAM" ]] && ccdc__set_team_output_dir "$TEAM" || true
    init_outputs
    menu_loop
  else
    [[ -n "$TEAM" ]] && ccdc_net__warn_if_team_out_of_range "$TEAM" || true
    [[ -n "$TEAM" ]] && ccdc__log_kv "Mapping" "$(ccdc_net__mapping_source)" || true
    [[ -n "$TEAM" ]] && ccdc__save_last_team "$TEAM" || true
    [[ -n "$TEAM" ]] && ccdc__set_team_output_dir "$TEAM" || true
    init_outputs
    run_full_checks
  fi
  return 0
}

main
