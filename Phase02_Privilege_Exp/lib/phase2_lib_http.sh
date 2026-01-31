#!/usr/bin/env bash
# lib/phase2_lib_http.sh
set -euo pipefail

# ============================================================
# Phase 2 HTTP Helper Library (read-only)
# Version : 0.1.0
#
# Principles:
# - Library should not exit the caller by default.
# - Return non-zero on failures; caller decides.
# - Low-noise helpers for recon: headers, tiny GET, titles, hints.
#
# Notes:
# - This lib stays standalone (no hard dependency on net scheme lib).
# - If phase2_lib_net_scheme.sh is loaded by the caller (it provides
#   ccdc_net__public_host), you can use phase2_http__url_for_team_host()
#   as a convenience helper.
# ============================================================

# -----------------------------
# Meta-aware defaults (Phase 2)
# -----------------------------
: "${HTTP_TIMEOUT_SEC_DEFAULT:=5}"
: "${PHASE_NAME:=Phase 2 (Privilege Expansion)}"

: "${PHASE2_HTTP_TIMEOUT_SECS:=${HTTP_TIMEOUT_SEC_DEFAULT}}"
: "${PHASE2_HTTP_CONNECT_TIMEOUT:=2}"
: "${PHASE2_HTTP_UA:=Mozilla/5.0 (${PHASE_NAME}; read-only)}"
: "${PHASE2_HTTP_FOLLOW_REDIRECTS:=0}"
: "${PHASE2_HTTP_TITLE_BYTES:=32768}"
: "${PHASE2_HTTP_MAX_REDIRS:=2}"

# -----------------------------
# Internal helpers
# -----------------------------
_phase2_http__warn() {
  local msg="$*"
  if declare -F phase2_warn >/dev/null 2>&1; then
    phase2_warn "$msg"
  else
    echo "WARN: $msg" >&2
  fi
}

_phase2_http__need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

_phase2_http__follow_args() {
  if [[ "${PHASE2_HTTP_FOLLOW_REDIRECTS}" == "1" ]]; then
    echo "-L --max-redirs ${PHASE2_HTTP_MAX_REDIRS}"
  else
    echo ""
  fi
}

# -----------------------------
# Public functions (Phase 2)
# -----------------------------
phase2_http__csv_safe() {
  # Remove newlines/commas/tabs; collapse whitespace (best-effort).
  local s="${1:-}"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  s="${s//$'\t'/ }"
  s="${s//,/ }"

  if _phase2_http__need_cmd sed; then
    echo "$s" | sed 's/[[:space:]]\+/ /g; s/^ *//; s/ *$//'
  else
    echo "$s"
  fi
}

phase2_http__is_html_ctype() {
  local ctype="${1:-}"
  echo "$ctype" | grep -qiE 'text/html|application/xhtml\+xml'
}

phase2_http__looks_like_html() {
  local body="${1:-}"
  echo "$body" | grep -qiE '<(html|title)\b'
}

phase2_http__extract_header() {
  local hdrs="${1:-}"
  local name="${2:-}"
  [[ -n "$hdrs" && -n "$name" ]] || { echo ""; return 0; }

  if ! _phase2_http__need_cmd awk; then
    _phase2_http__warn "awk missing; cannot extract headers"
    echo ""
    return 1
  fi

  echo "$hdrs" | awk -v IGNORECASE=1 -v h="$name" '
    $0 ~ "^"h":" {
      sub("^[^:]+:[[:space:]]*", "", $0);
      print $0;
      exit
    }'
}

phase2_http__extract_last_status() {
  local hdrs="${1:-}"
  [[ -n "$hdrs" ]] || { echo "NO"; return 0; }

  if ! _phase2_http__need_cmd awk; then
    _phase2_http__warn "awk missing; cannot parse HTTP status"
    echo "NO"
    return 1
  fi

  echo "$hdrs" | awk 'BEGIN{code="NO"} toupper($0) ~ /^HTTP\// {code=$2} END{print code}'
}

phase2_http__url_for_ip_port() {
  # Usage: phase2_http__url_for_ip_port "http" "172.25.21.10" "80" "/admin"
  local scheme="${1:-http}"
  local ip="${2:-}"
  local port="${3:-80}"
  local path="${4:-/}"
  echo "${scheme}://${ip}:${port}${path}"
}

phase2_http__url_for_team_host() {
  # Optional convenience helper.
  # Requires ccdc_net__public_host to exist (provided by Phase 2 net scheme lib).
  #
  # Usage:
  #   url="$(phase2_http__url_for_team_host "$TEAM" 10 "https" 443 "/")"
  local team="${1:-}"
  local host="${2:-}"
  local scheme="${3:-http}"
  local port="${4:-80}"
  local path="${5:-/}"

  if ! declare -F ccdc_net__public_host >/dev/null 2>&1; then
    _phase2_http__warn "ccdc_net__public_host not found (source phase2_lib_net_scheme.sh in caller)."
    return 1
  fi

  local ip
  ip="$(ccdc_net__public_host "$team" "$host" 2>/dev/null || true)"
  [[ -n "$ip" ]] || return 1
  echo "${scheme}://${ip}:${port}${path}"
  return 0
}

phase2_http__curl_headers() {
  local url="${1:-}"
  [[ -n "$url" ]] || return 1
  _phase2_http__need_cmd curl || { _phase2_http__warn "curl missing"; return 1; }

  # shellcheck disable=SC2206
  local follow_args=($(_phase2_http__follow_args))

  curl -sS \
    --connect-timeout "${PHASE2_HTTP_CONNECT_TIMEOUT}" \
    --max-time "${PHASE2_HTTP_TIMEOUT_SECS}" \
    -A "${PHASE2_HTTP_UA}" \
    "${follow_args[@]}" \
    -D - \
    -o /dev/null \
    "$url" 2>/dev/null
}

phase2_http__curl_tiny_get() {
  local url="${1:-}"
  [[ -n "$url" ]] || return 1
  _phase2_http__need_cmd curl || { _phase2_http__warn "curl missing"; return 1; }

  # shellcheck disable=SC2206
  local follow_args=($(_phase2_http__follow_args))

  curl -sS \
    --connect-timeout "${PHASE2_HTTP_CONNECT_TIMEOUT}" \
    --max-time "${PHASE2_HTTP_TIMEOUT_SECS}" \
    -A "${PHASE2_HTTP_UA}" \
    "${follow_args[@]}" \
    --range "0-${PHASE2_HTTP_TITLE_BYTES}" \
    "$url" 2>/dev/null || true
}

phase2_http__extract_title() {
  _phase2_http__need_cmd tr || return 1
  _phase2_http__need_cmd head || return 1
  _phase2_http__need_cmd sed || return 1

  tr '\r\n' ' ' \
    | sed -n 's/.*<title[^>]*>\(.*\)<\/title>.*/\1/ip' \
    | head -n 1 \
    | sed 's/[[:space:]]\+/ /g; s/^ *//; s/ *$//'
}

phase2_http__title_if_html() {
  local url="${1:-}"
  local ctype="${2:-}"
  [[ -n "$url" ]] || { echo ""; return 0; }

  if phase2_http__is_html_ctype "$ctype"; then
    phase2_http__curl_tiny_get "$url" | phase2_http__extract_title
    return 0
  fi

  if [[ -z "$ctype" ]]; then
    local body
    body="$(phase2_http__curl_tiny_get "$url")"
    if phase2_http__looks_like_html "$body"; then
      echo "$body" | phase2_http__extract_title
      return 0
    fi
  fi

  echo ""
  return 0
}

phase2_http__normalize_url() {
  local s="${1:-}"
  if [[ "$s" =~ ^httpsNO:// ]]; then
    echo "$s"
  else
    echo "http://${s}"
  fi
}

phase2_http__guess_scheme() {
  local ip="${1:-}"
  [[ -n "$ip" ]] || { echo ""; return 0; }

  if phase2_http__curl_headers "https://${ip}:443/" >/dev/null 2>&1; then
    echo "https"
    return 0
  fi
  if phase2_http__curl_headers "http://${ip}:80/" >/dev/null 2>&1; then
    echo "http"
    return 0
  fi
  echo ""
  return 0
}

phase2_http__fingerprint_hints() {
  if ! _phase2_http__need_cmd grep; then
    _phase2_http__warn "grep missing; cannot fingerprint hints"
    echo ""
    return 1
  fi

  local tags
  tags="$(
    tr '\r\n' ' ' 2>/dev/null \
      | grep -Eoi 'opencart|splunk|roundcube|squirrelmail|zimbra|owa|grafana|prometheus|jenkins|phpmyadmin|cpanel|webmail|login|admin' \
      | head -n 25 2>/dev/null \
      | tr '\n' ' ' 2>/dev/null
  )"

  tags="$(phase2_http__csv_safe "$tags")"
  if _phase2_http__need_cmd awk; then
    echo "$tags" | awk '{for(i=1;i<=NF;i++){if(!seen[$i]++){out=out $i " "}}} END{gsub(/[[:space:]]+$/,"",out); print out}'
  else
    echo "$tags"
  fi
}

phase2_http__tls_cn() {
  local ip="${1:-}"
  [[ -n "$ip" ]] || { echo ""; return 0; }

  if ! _phase2_http__need_cmd openssl; then
    echo ""
    return 0
  fi

  if _phase2_http__need_cmd timeout; then
    timeout 2 openssl s_client -connect "${ip}:443" -servername "$ip" </dev/null 2>/dev/null \
      | openssl x509 -noout -subject 2>/dev/null \
      | sed -n 's/.*CN=\([^,/]*\).*/\1/p' \
      | head -n 1 || true
  else
    openssl s_client -connect "${ip}:443" -servername "$ip" </dev/null 2>/dev/null \
      | openssl x509 -noout -subject 2>/dev/null \
      | sed -n 's/.*CN=\([^,/]*\).*/\1/p' \
      | head -n 1 || true
  fi
}

phase2_http__fetch_fields() {
  # Returns pipe-delimited:
  # status|server|x-powered-by|content-type|location|www-authenticate
  local url="${1:-}"
  [[ -n "$url" ]] || { echo "|||||"; return 1; }

  local hdrs status server xpb ctype loc auth
  hdrs="$(phase2_http__curl_headers "$url" 2>/dev/null || true)"
  [[ -n "$hdrs" ]] || { echo "|||||"; return 1; }

  status="$(phase2_http__extract_last_status "$hdrs" || echo "NO")"
  server="$(phase2_http__extract_header "$hdrs" "Server" || true)"
  xpb="$(phase2_http__extract_header "$hdrs" "X-Powered-By" || true)"
  ctype="$(phase2_http__extract_header "$hdrs" "Content-Type" || true)"
  loc="$(phase2_http__extract_header "$hdrs" "Location" || true)"
  auth="$(phase2_http__extract_header "$hdrs" "WWW-Authenticate" || true)"

  echo "${status}|${server}|${xpb}|${ctype}|${loc}|${auth}"
}
