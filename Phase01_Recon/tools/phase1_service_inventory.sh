#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_service_inventory.sh
# Purpose : Phase-1 read-only service inventory (HTTP/HTTPS)
# Version : 0.6.0
#
# Usage:
#   ./phase1_service_inventory.sh
#   ./phase1_service_inventory.sh <TEAM_NUMBER>
#
# Output (Phase 1 dirs; overwritten each run):
#   ./logs/phase1_service_inventory.log
#   ./output/services.txt
#   ./output/services.csv
#   ./output/services_hits.txt
#   ./output/targets_all.txt
#   ./output/targets_candidates.txt
#
# Notes:
# - Low-noise: only HTTP/HTTPS requests (80/443).
# - No exploitation. No brute force. No auth attempts.
# ============================================================

TEAM_ARG="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "${SCRIPT_DIR}/lib" ]] || SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---- Import libs (Phase 1 local lib only) ----
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_runtime.sh" || { echo "ERROR: Missing lib/ccdc_runtime.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_utils.sh"   || { echo "ERROR: Missing lib/ccdc_utils.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_http.sh"    || { echo "ERROR: Missing lib/ccdc_http.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_menu.sh"    || { echo "ERROR: Missing lib/ccdc_menu.sh"; exit 3; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ccdc_net_scheme.sh" || { echo "ERROR: Missing lib/ccdc_net_scheme.sh"; exit 3; }

# ---- Tunables (no CLI flags) ----
# Limit total hosts to scan (default full /24)
MAX_HOSTS="${CCDC_PHASE1_MAX_HOSTS:-254}"
# Optional max runtime (seconds). 0 = no limit.
MAX_SECONDS="${CCDC_PHASE1_MAX_SECONDS:-0}"
# Progress log cadence
PROGRESS_EVERY="${CCDC_PHASE1_PROGRESS_EVERY:-25}"

# Wire tunables into HTTP lib env vars
export CCDC_HTTP_TIMEOUT_SECS="2"
export CCDC_HTTP_CONNECT_TIMEOUT="1"
export CCDC_HTTP_UA="Mozilla/5.0 (CCDC Phase1 Inventory; read-only)"
export CCDC_HTTP_FOLLOW_REDIRECTS="0"
export CCDC_HTTP_TITLE_BYTES="32768"
export CCDC_HTTP_MAX_REDIRS="2"

# Output paths
TXT_OUT=""
CSV_OUT=""
HITS_OUT=""
TARGETS_ALL=""
TARGETS_CAND=""

usage() {
  ccdc__usage_team "$(basename "$0")"
}

init_outputs() {
  mkdir -p "$CCDC_OUT_DIR" 2>/dev/null || true
  TXT_OUT="${CCDC_OUT_DIR}/services.txt"
  CSV_OUT="${CCDC_OUT_DIR}/services.csv"
  HITS_OUT="${CCDC_OUT_DIR}/services_hits.txt"
  TARGETS_ALL="${CCDC_OUT_DIR}/targets_all.txt"
  TARGETS_CAND="${CCDC_OUT_DIR}/targets_candidates.txt"
  RANKED_OUT="${CCDC_OUT_DIR}/targets_ranked.csv"

  : > "$TXT_OUT"
  : > "$CSV_OUT"
  : > "$HITS_OUT"
  : > "$TARGETS_ALL"
  : > "$TARGETS_CAND"
  : > "$RANKED_OUT"

  echo "ip,scheme,port,status,server,x_powered_by,content_type,www_authenticate,location,tls_cn,title" > "$CSV_OUT"
  echo "rank,score,ip,reason" > "$RANKED_OUT"
}

write_header() {
  local target_net="$1"
  {
    echo "[*] Phase 1 Service Inventory (read-only)"
    echo "[*] Target Net: ${target_net}"
    echo "[*] Output: $(basename "$TXT_OUT"), $(basename "$CSV_OUT"), $(basename "$HITS_OUT")"
    echo "[*] Targets: $(basename "$TARGETS_ALL"), $(basename "$TARGETS_CAND")"
    echo "[*] Settings: timeout=${CCDC_HTTP_TIMEOUT_SECS}s connect_timeout=${CCDC_HTTP_CONNECT_TIMEOUT}s follow=${CCDC_HTTP_FOLLOW_REDIRECTS}"
    echo "[*] Limits: max_hosts=${MAX_HOSTS} max_seconds=${MAX_SECONDS}"
    echo "--------------------------------------------------------------------------------"
  } > "$TXT_OUT"
}

probe_one() {
  local ip="$1"
  local scheme="$2"
  local port="$3"
  local url
  url="$(ccdc_http__url_for_ip_port "$scheme" "$ip" "$port" "/")"

  # status|server|xpb|ctype|loc|auth
  local fields status server xpb ctype loc auth
  fields="$(ccdc_http__fetch_fields "$url" 2>/dev/null || true)"
  [[ -n "$fields" && "$fields" != "|||||" ]] || return 0

  status="${fields%%|*}"; fields="${fields#*|}"
  server="${fields%%|*}"; fields="${fields#*|}"
  xpb="${fields%%|*}"; fields="${fields#*|}"
  ctype="${fields%%|*}"; fields="${fields#*|}"
  loc="${fields%%|*}"; fields="${fields#*|}"
  auth="${fields}"

  local title cn
  title=""
  if [[ "$status" =~ ^[23] ]]; then
    title="$(ccdc_http__title_if_html "$url" "${ctype:-}")"
  fi

  cn=""
  if [[ "$scheme" == "https" ]]; then
    cn="$(ccdc_http__tls_cn "$ip")"
  fi

  # CSV safety
  server="$(ccdc_http__csv_safe "${server:-}")"
  xpb="$(ccdc_http__csv_safe "${xpb:-}")"
  ctype="$(ccdc_http__csv_safe "${ctype:-}")"
  loc="$(ccdc_http__csv_safe "${loc:-}")"
  auth="$(ccdc_http__csv_safe "${auth:-}")"
  cn="$(ccdc_http__csv_safe "${cn:-}")"
  title="$(ccdc_http__csv_safe "${title:-}")"

  printf "%-15s %-5s %-4s status=%-3s server=%s xpb=%s ctype=%s auth=%s loc=%s cn=%s title=%s\n" \
    "$ip" "$scheme" "$port" "${status:-"NO"}" \
    "${server:-"-"}" "${xpb:-"-"}" "${ctype:-"-"}" "${auth:-"-"}" "${loc:-"-"}" "${cn:-"-"}" "${title:-"-"}" \
    >> "$TXT_OUT"

  echo "$ip,$scheme,$port,${status:-},${server:-},${xpb:-},${ctype:-},${auth:-},${loc:-},${cn:-},${title:-}" >> "$CSV_OUT"

  if [[ -n "${auth:-}" || -n "${loc:-}" || -n "${server:-}" || -n "${title:-}" ]]; then
    printf "%s %s:%s status=%s server=%s title=%s loc=%s auth=%s\n" \
      "$ip" "$scheme" "$port" "${status:-"-"}" "${server:-"-"}" "${title:-"-"}" "${loc:-"-"}" "${auth:-"-"}" \
      >> "$HITS_OUT"
  fi
}

scan_host() {
  local ip="$1"
  probe_one "$ip" "http" "80"  || true
  probe_one "$ip" "https" "443" || true
}

write_summary() {
  {
    echo ""
    echo "============================== SUMMARY =============================="
    echo "[*] Top Server headers (count):"
    awk -F',' 'NR>1 && $5!="" {print $5}' "$CSV_OUT" | sed 's/^ *//; s/ *$//' | sort | uniq -c | sort -nr | head -n 10
    echo ""
    echo "[*] Top Titles (count):"
    awk -F',' 'NR>1 && $11!="" {print $11}' "$CSV_OUT" | sed 's/^ *//; s/ *$//' | sort | uniq -c | sort -nr | head -n 10
    echo ""
    echo "[*] Likely web apps (status 200/301/302 with PHP-ish hints):"
    awk -F',' '
      NR>1 {
        ip=$1; scheme=$2; port=$3; status=$4; xpb=$6; title=$11;
        if ((status=="200"||status=="301"||status=="302") &&
            (tolower(xpb) ~ /php/ || tolower(title) ~ /opencart|login|admin|mail|splunk|dashboard/)) {
          printf("%s %s:%s status=%s xpb=%s title=%s\n", ip, scheme, port, status, xpb, title);
        }
      }' "$CSV_OUT" | head -n 30
    echo "===================================================================="
    echo ""
  } >> "$TXT_OUT"
}

rank_targets() {
  awk -F',' '
    NR>1 {
      ip=$1; scheme=$2; status=$4; server=tolower($5); xpb=tolower($6); title=tolower($11);
      score=0; reason="";
      if (status=="200") {score+=2; reason=reason "200 ";}
      if (status=="301"||status=="302") {score+=1; reason=reason "redir ";}
      if (server ~ /apache|nginx|iis/) {score+=2; reason=reason "server ";}
      if (xpb ~ /php|asp|jsp/) {score+=2; reason=reason "xpb ";}
      if (title ~ /login|admin|mail|webmail|splunk|opencart|dashboard/) {score+=3; reason=reason "title ";}
      if (score>0) print score "," ip "," reason;
    }
  ' "$CSV_OUT" | sort -t',' -k1,1nr -k2,2 | awk -F',' 'BEGIN{rank=0}{rank++; printf("%d,%s,%s,%s\n",rank,$1,$2,$3)}' >> "$RANKED_OUT"
}
build_targets() {
  # Build two target lists using net scheme lib
  ccdc_net__public_hosts_range "$TEAM" > "$TARGETS_ALL" 2>/dev/null || true
  ccdc_net__public_host_candidates "$TEAM" > "$TARGETS_CAND" 2>/dev/null || true
}

run_scan() {
  local target_net
  target_net="$(ccdc__target_net "$TEAM")"

  ccdc__section "Scanning ${target_net} (HTTP/HTTPS only)"
  write_header "$target_net"
  build_targets

  # Scan the full list (1..254)
  local start_ts now_ts elapsed count
  start_ts="$(date +%s 2>/dev/null || echo 0)"
  count=0
  while read -r ip; do
    [[ -n "$ip" ]] || continue
    count=$((count + 1))
    if [[ "$MAX_HOSTS" =~ ^[0-9]+$ ]] && (( count > MAX_HOSTS )); then
      ccdc__log "[*] Reached max_hosts=${MAX_HOSTS}; stopping scan early."
      break
    fi
    if [[ "$MAX_SECONDS" =~ ^[0-9]+$ ]] && (( MAX_SECONDS > 0 )); then
      now_ts="$(date +%s 2>/dev/null || echo 0)"
      elapsed=$((now_ts - start_ts))
      if (( elapsed >= MAX_SECONDS )); then
        ccdc__log "[*] Reached max_seconds=${MAX_SECONDS}; stopping scan early."
        break
      fi
    fi
    scan_host "$ip"
    if [[ "$PROGRESS_EVERY" =~ ^[0-9]+$ ]] && (( PROGRESS_EVERY > 0 )); then
      if (( count % PROGRESS_EVERY == 0 )); then
        ccdc__log "[*] Progress: ${count} hosts scanned..."
      fi
    fi
  done < "$TARGETS_ALL"

  write_summary
  rank_targets

  {
    echo "--------------------------------------------------------------------------------"
    echo "[*] Done."
    echo "[*] Wrote: $TXT_OUT"
    echo "[*] Wrote: $CSV_OUT"
    echo "[*] Wrote: $HITS_OUT"
    echo "[*] Wrote: $TARGETS_ALL"
    echo "[*] Wrote: $TARGETS_CAND"
    echo "[*] Wrote: $RANKED_OUT"
  } >> "$TXT_OUT"

  ccdc__log "[*] Scan complete."
  ccdc__log "    $TXT_OUT"
  ccdc__log "    $CSV_OUT"
  ccdc__log "    $HITS_OUT"
}

menu_loop() {
  while true; do
    ccdc_menu__header "Phase 1 -- Service Inventory" "Read-only HTTP/HTTPS inventory"
    ccdc__log_kv "Team" "$TEAM"
    ccdc__log_kv "Public subnet" "$(ccdc__target_net "$TEAM")"
    echo ""

    local choice
    choice="$(ccdc_menu__choose "Select action" 1 \
      "Run scan (overwrite outputs)" \
      "View services_hits.txt" \
      "View services.txt" \
      "View services.csv" \
      "View targets_candidates.txt" \
      "Exit")"

    case "$choice" in
      1) run_scan; ccdc_menu__pause ;;
      2) ccdc__open_viewer "$HITS_OUT" || true; ccdc_menu__pause ;;
      3) ccdc__open_viewer "$TXT_OUT" || true; ccdc_menu__pause ;;
      4) ccdc__open_viewer "$CSV_OUT" || true; ccdc_menu__pause ;;
      5) ccdc__open_viewer "$TARGETS_CAND" || true; ccdc_menu__pause ;;
      0|6) return 0 ;;
    esac
  done
}

main() {
  ccdc__init_run "phase1_service_inventory" || exit 1

  TEAM=""
  if TEAM_PARSED="$(ccdc__parse_team_or_last "$TEAM_ARG" 2>/dev/null)"; then
    TEAM="$TEAM_PARSED"
  fi

  # Required tools
  ccdc__require_cmds curl awk sed tr head sort uniq || exit 3

  if ccdc_menu__is_interactive; then
    TEAM="$(ccdc_menu__pick_team "$TEAM" "0")" || return 0
    ccdc_net__warn_if_team_out_of_range "$TEAM" || true
    ccdc__log_kv "Mapping" "$(ccdc_net__mapping_source)"
    ccdc__save_last_team "$TEAM" || ccdc__warn "Could not save output/team.txt (continuing)"
    ccdc__set_team_output_dir "$TEAM" || ccdc__warn "Could not set team output dir (continuing)"
    init_outputs
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
    init_outputs
    ccdc_net__print_team_summary "$TEAM" || true
    run_scan
  fi

  return 0
}

main
