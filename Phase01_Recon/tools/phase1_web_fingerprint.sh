#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_web_fingerprint.sh
# Purpose : Phase 1 - Light web fingerprinting (read-only)
# Version : 0.3.0
#
# Usage:
#   ./phase1_web_fingerprint.sh
#   ./phase1_web_fingerprint.sh <TEAM_NUMBER>
#
# Output (Phase 1 dirs; overwritten each run):
#   ./logs/phase1_web_fingerprint.log
#   ./output/web_fingerprint.txt
#   ./output/web_fingerprint.csv
#   ./output/web_fingerprint_targets_used.txt
#
# Notes:
# - Low-noise: a handful of requests per host.
# - No brute force, no dirbusting, no exploitation.
# - Target selection prefers:
#     services.csv -> ops_known_hosts.csv -> targets_candidates.txt ->
#     services_hits.txt -> full public /24
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

TEAM=""
TXT_OUT=""
CSV_OUT=""
TARGETS_USED=""
TARGETS_USED_MODE="ip"

# HTTP lib settings
export CCDC_HTTP_TIMEOUT_SECS="3"
export CCDC_HTTP_CONNECT_TIMEOUT="2"
export CCDC_HTTP_UA="Mozilla/5.0 (CCDC Phase1 Fingerprint; read-only)"
export CCDC_HTTP_FOLLOW_REDIRECTS="0"
export CCDC_HTTP_TITLE_BYTES="65535"
export CCDC_HTTP_MAX_REDIRS="2"

# Small allowlist of paths that are high-signal and low-noise
PATHS=(
  "/"
  "/robots.txt"
  "/admin"
  "/login"
  "/administrator"
  "/index.php"
)

# Optional cap on number of targets used (0 = no limit)
FP_MAX_HOSTS="${CCDC_PHASE1_FP_MAX_HOSTS:-0}"
# Ports to probe (comma or space separated)
FP_PORTS="${CCDC_PHASE1_FP_PORTS:-80,443,8080,8443}"
FP_PORTS_CLEAN="$(echo "${FP_PORTS}" | tr ',' ' ')"
read -r -a FP_PORT_LIST <<< "${FP_PORTS_CLEAN}"

usage() { ccdc__usage_team "$(basename "$0")"; }

init_outputs() {
  mkdir -p "$CCDC_OUT_DIR" 2>/dev/null || true
  TXT_OUT="${CCDC_OUT_DIR}/web_fingerprint.txt"
  CSV_OUT="${CCDC_OUT_DIR}/web_fingerprint.csv"
  TARGETS_USED="${CCDC_OUT_DIR}/web_fingerprint_targets_used.txt"

  : > "$TXT_OUT"
  : > "$TARGETS_USED"
  echo "ip,scheme,port,path,status,title,server,x_powered_by,content_type,set_cookie,location,hints" > "$CSV_OUT"
}

write_targets_used_from_file() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  cat "$f" 2>/dev/null | sed '/^\s*$/d' | sort -u > "$TARGETS_USED"
  [[ -s "$TARGETS_USED" ]] || return 1
  return 0
}

extract_targets_from_hits() {
  local hits="$1"
  [[ -f "$hits" ]] || return 1
  local oct
  oct="$(ccdc_net__team_octet "$TEAM" 2>/dev/null || true)"
  [[ -n "$oct" ]] || return 1
  # first token is IP in our hits format
  awk -v oct="$oct" '$1 ~ ("^172\.25\."oct"\.") {print $1}' "$hits" 2>/dev/null | sort -u
}

build_targets_used() {
  # Prefer services.csv (highest signal), then known hosts, then candidates, then hits, then full public range
  local services_csv="${CCDC_OUT_DIR}/services.csv"
  local cand="${CCDC_OUT_DIR}/targets_candidates.txt"
  local hits="${CCDC_OUT_DIR}/services_hits.txt"
  local base known
  base="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  known="${CCDC_KNOWN_HOSTS_CSV:-${base}/data/ops_known_hosts.csv}"

  if [[ -f "$services_csv" ]]; then
    ccdc__log "[*] Using targets from services.csv: $services_csv"
    awk -F',' 'NR>1 && $1!="" {print $1","$2","$3}' "$services_csv" | sort -u > "$TARGETS_USED"
    if [[ -s "$TARGETS_USED" ]]; then
      TARGETS_USED_MODE="tuple"
      return 0
    fi
    ccdc__warn "services.csv is empty; falling back to candidates/hits/full scan."
  fi

  if [[ -f "$known" ]]; then
    ccdc__log "[*] Using targets from ops_known_hosts.csv: $known"
    local oct
    oct="$(ccdc_net__team_octet "$TEAM" 2>/dev/null || true)"
    if [[ -n "$oct" ]]; then
      awk -F',' -v team="$TEAM" -v oct="$oct" '
        NR==1 {next}
        {
          t=$1; ip=$2;
          gsub(/^[ \t]+|[ \t]+$/, "", t);
          gsub(/^[ \t]+|[ \t]+$/, "", ip);
          if (t==team && ip ~ "^172\\.25\\."oct"\\.") print ip;
        }
      ' "$known" | sort -u > "$TARGETS_USED"
      if [[ -s "$TARGETS_USED" ]]; then
        TARGETS_USED_MODE="ip"
        return 0
      fi
    fi
  fi

  if [[ -f "$cand" ]]; then
    ccdc__log "[*] Using targets from candidates: $cand"
    if write_targets_used_from_file "$cand"; then
      TARGETS_USED_MODE="ip"
      return 0
    fi
    ccdc__warn "Candidates list is empty; falling back to hits/full scan."
  fi

  if [[ -f "$hits" ]]; then
    ccdc__log "[*] Using targets from hits: $hits"
    extract_targets_from_hits "$hits" > "$TARGETS_USED"
    if [[ -s "$TARGETS_USED" ]]; then
      TARGETS_USED_MODE="ip"
      return 0
    fi
  fi

  ccdc__warn "No candidates/hits found; using full public /24 (this is slower)"
  ccdc_net__public_hosts_range "$TEAM" > "$TARGETS_USED" 2>/dev/null || return 1
  TARGETS_USED_MODE="ip"
  return 0
}

apply_target_limit() {
  if [[ "$FP_MAX_HOSTS" =~ ^[0-9]+$ ]] && (( FP_MAX_HOSTS > 0 )); then
    ccdc__log "[*] Limiting targets to first ${FP_MAX_HOSTS} hosts"
    head -n "$FP_MAX_HOSTS" "$TARGETS_USED" > "${TARGETS_USED}.tmp" 2>/dev/null || true
    mv "${TARGETS_USED}.tmp" "$TARGETS_USED" 2>/dev/null || true
  fi
  return 0
}

probe_url() {
  local ip="$1"
  local scheme="$2"
  local port="$3"
  local path="$4"

  local url fields status server xpb ctype loc auth
  url="$(ccdc_http__url_for_ip_port "$scheme" "$ip" "$port" "$path")"

  # status|server|xpb|ctype|loc|auth
  fields="$(ccdc_http__fetch_fields "$url" 2>/dev/null || true)"
  [[ -n "$fields" && "$fields" != "|||||" ]] || return 0

  status="${fields%%|*}"; fields="${fields#*|}"
  server="${fields%%|*}"; fields="${fields#*|}"
  xpb="${fields%%|*}"; fields="${fields#*|}"
  ctype="${fields%%|*}"; fields="${fields#*|}"
  loc="${fields%%|*}"; fields="${fields#*|}"
  auth="${fields}"

  local body title hints cookie hdrs
  body="$(ccdc_http__curl_tiny_get "$url")"

  title=""
  if [[ "$status" =~ ^[23] ]]; then
    title="$(echo "$body" | ccdc_http__extract_title 2>/dev/null || true)"
    [[ -z "$title" ]] && title="$(ccdc_http__title_if_html "$url" "${ctype:-}")"
  fi

  hints="$(echo "$body" | ccdc_http__fingerprint_hints 2>/dev/null || true)"

  # Cookie: only for path "/" to keep noise down
  cookie=""
  if [[ "$path" == "/" ]]; then
    hdrs="$(ccdc_http__curl_headers "$url" 2>/dev/null || true)"
    cookie="$(ccdc_http__extract_header "$hdrs" "Set-Cookie" 2>/dev/null || true)"
  fi

  # CSV safety
  title="$(ccdc_http__csv_safe "$title")"
  server="$(ccdc_http__csv_safe "$server")"
  xpb="$(ccdc_http__csv_safe "$xpb")"
  ctype="$(ccdc_http__csv_safe "$ctype")"
  cookie="$(ccdc_http__csv_safe "$cookie")"
  loc="$(ccdc_http__csv_safe "$loc")"
  hints="$(ccdc_http__csv_safe "$hints")"

  printf "%-15s %-5s %-4s %-18s status=%-3s title=%s hints=%s\n" \
    "$ip" "$scheme" "$port" "$path" "${status:-"-"}" "${title:-"-"}" "${hints:-"-"}" \
    >> "$TXT_OUT"

  echo "$ip,$scheme,$port,$path,${status:-},${title:-},${server:-},${xpb:-},${ctype:-},${cookie:-},${loc:-},${hints:-}" \
    >> "$CSV_OUT"
}

probe_host() {
  local ip="$1"
  local scheme="$2"
  local port="$3"
  local p
  for p in "${PATHS[@]}"; do
    probe_url "$ip" "$scheme" "$port" "$p" || true
  done
}

port_to_scheme() {
  local port="${1:-}"
  case "$port" in
    443|8443) echo "https" ;;
    *) echo "http" ;;
  esac
}

run_fingerprint() {
  ccdc__section "Phase 1 Web Fingerprint (read-only)"
  ccdc__log_kv "Team" "$TEAM"
  ccdc__log_kv "Public subnet" "$(ccdc__target_net "$TEAM")"
  ccdc__log_kv "Ports" "${FP_PORTS_CLEAN}"

  # Print full net scheme summary for operator context
  ccdc_net__print_team_summary "$TEAM" || true

  init_outputs
  build_targets_used
  apply_target_limit

  ccdc__log "[*] Targets used: $TARGETS_USED ($(wc -l < "$TARGETS_USED" 2>/dev/null || echo "NO") hosts)"

  local ip scheme port
  if [[ "$TARGETS_USED_MODE" == "tuple" ]]; then
    while IFS=',' read -r ip scheme port; do
      [[ -n "$ip" ]] || continue
      if [[ -z "${port:-}" ]]; then
        for port in "${FP_PORT_LIST[@]}"; do
          [[ -n "$port" ]] || continue
          scheme="$(port_to_scheme "$port")"
          probe_host "$ip" "$scheme" "$port"
        done
      else
        if [[ -z "${scheme:-}" ]]; then
          scheme="$(port_to_scheme "$port")"
        fi
        probe_host "$ip" "$scheme" "$port"
      fi
    done < "$TARGETS_USED"
  else
    while read -r ip; do
      [[ -n "$ip" ]] || continue
      for port in "${FP_PORT_LIST[@]}"; do
        [[ -n "$port" ]] || continue
        scheme="$(port_to_scheme "$port")"
        probe_host "$ip" "$scheme" "$port"
      done
    done < "$TARGETS_USED"
  fi

  ccdc__section "Done"
  ccdc__log "[*] Wrote: $TXT_OUT"
  ccdc__log "[*] Wrote: $CSV_OUT"
  ccdc__log "[*] Wrote: $TARGETS_USED"
  # Optional: keep a slim "hits only" file for quick review
  if [[ -f "$CSV_OUT" ]]; then
    awk -F',' 'NR==1 {print $0; next} $5!="" || $6!="" || $12!="" {print $0}' "$CSV_OUT" > "${CCDC_OUT_DIR}/web_fingerprint_hits.csv" 2>/dev/null || true
  fi
}

view_outputs_menu() {
  local choice file
  while true; do
    ccdc_menu__header "Phase 1 -- Web Fingerprint Outputs" "Choose a file to view"
    choice="$(ccdc_menu__choose "Select output" 1 \
      "web_fingerprint.txt" \
      "web_fingerprint.csv" \
      "web_fingerprint_targets_used.txt" \
      "targets_candidates.txt (if present)" \
      "services_hits.txt (if present)" \
      "Back")"

    case "$choice" in
      1) file="$TXT_OUT" ;;
      2) file="$CSV_OUT" ;;
      3) file="$TARGETS_USED" ;;
      4) file="${CCDC_OUT_DIR}/targets_candidates.txt" ;;
      5) file="${CCDC_OUT_DIR}/services_hits.txt" ;;
      0|6) return 0 ;;
    esac

    ccdc__open_viewer "$file" || true
    ccdc_menu__pause
  done
}

menu_loop() {
  while true; do
    ccdc_menu__header "Phase 1 -- Web Fingerprint" "Read-only light fingerprinting"
    ccdc__log_kv "Team" "$TEAM"
    ccdc__log_kv "Public subnet" "$(ccdc__target_net "$TEAM")"
    ccdc__log_kv "Outputs" "${CCDC_OUT_DIR}"
    echo ""

    local choice
    choice="$(ccdc_menu__choose "Select action" 1 \
      "Run fingerprint (overwrite outputs)" \
      "View outputs" \
      "Exit")"

    case "$choice" in
      1) run_fingerprint; ccdc_menu__pause ;;
      2) view_outputs_menu ;;
      0|3) return 0 ;;
    esac
  done
}

main() {
  ccdc__init_run "phase1_web_fingerprint" || exit 1

  TEAM=""
  if TEAM_PARSED="$(ccdc__parse_team_or_last "$TEAM_ARG" 2>/dev/null)"; then
    TEAM="$TEAM_PARSED"
  fi

  ccdc__require_cmds curl awk sed tr head sort uniq grep wc || exit 3

  if [[ "${CCDC_BATCH:-0}" == "1" || "${CCDC_TEAM_LOCK:-0}" == "1" ]]; then
    if [[ -z "${TEAM:-}" ]]; then
      ccdc__warn "Team not set for batch run."
      return 1
    fi
    ccdc_net__warn_if_team_out_of_range "$TEAM" || true
    ccdc__log_kv "Mapping" "$(ccdc_net__mapping_source)"
    ccdc__save_last_team "$TEAM" || ccdc__warn "Could not save output/team.txt (continuing)"
    ccdc__set_team_output_dir "$TEAM" || ccdc__warn "Could not set team output dir (continuing)"

    TXT_OUT="${CCDC_OUT_DIR}/web_fingerprint.txt"
    CSV_OUT="${CCDC_OUT_DIR}/web_fingerprint.csv"
    TARGETS_USED="${CCDC_OUT_DIR}/web_fingerprint_targets_used.txt"
    run_fingerprint
    return 0
  fi

  if ccdc_menu__is_interactive; then
    TEAM="$(ccdc_menu__pick_team "$TEAM" "0")" || return 0
    ccdc_net__warn_if_team_out_of_range "$TEAM" || true
    ccdc__log_kv "Mapping" "$(ccdc_net__mapping_source)"
    ccdc__save_last_team "$TEAM" || ccdc__warn "Could not save output/team.txt (continuing)"
    ccdc__set_team_output_dir "$TEAM" || ccdc__warn "Could not set team output dir (continuing)"

    # set default output paths so menu viewing works even before run
    TXT_OUT="${CCDC_OUT_DIR}/web_fingerprint.txt"
    CSV_OUT="${CCDC_OUT_DIR}/web_fingerprint.csv"
    TARGETS_USED="${CCDC_OUT_DIR}/web_fingerprint_targets_used.txt"
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

    # set default output paths so menu viewing works even before run
    TXT_OUT="${CCDC_OUT_DIR}/web_fingerprint.txt"
    CSV_OUT="${CCDC_OUT_DIR}/web_fingerprint.csv"
    TARGETS_USED="${CCDC_OUT_DIR}/web_fingerprint_targets_used.txt"
    run_fingerprint
  fi
  return 0
}

main
