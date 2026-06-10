#!/usr/bin/env bash
# lib/ccdc_http.sh
set -euo pipefail

# ============================================================
# Phase 1 HTTP Helper Library (read-only)
# Version : 0.3.1
#
# Principles:
# - Library should not exit the caller by default.
# - Return non-zero on failures; caller decides.
# - Low-noise helpers for recon: headers, tiny GET, titles, hints.
#
# Notes:
# - This lib stays standalone (no hard dependency on ccdc_net_scheme.sh).
# - If ccdc_net_scheme.sh is loaded by the caller, you can use
#   ccdc_http__url_for_team_host() as a convenience helper.
# ============================================================

# Expect callers to set these (or defaults apply):
: "${CCDC_HTTP_TIMEOUT_SECS:=2}"
: "${CCDC_HTTP_CONNECT_TIMEOUT:=1}"
: "${CCDC_HTTP_UA:=Mozilla/5.0 (CCDC Phase1; read-only)}"
: "${CCDC_HTTP_FOLLOW_REDIRECTS:=0}"
: "${CCDC_HTTP_TITLE_BYTES:=32768}"
: "${CCDC_HTTP_MAX_REDIRS:=2}"

# Optional hook: use ccdc__warn if available (from ccdc_runtime.sh)
_ccdc_http__warn() {
  local msg="$*"
  if declare -F ccdc__warn >/dev/null 2>&1; then
    ccdc__warn "$msg"
  else
    echo "WARN: $msg" >&2
  fi
}

_ccdc_http__need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

_ccdc_http__follow_args() {
  if [[ "${CCDC_HTTP_FOLLOW_REDIRECTS}" == "1" ]]; then
    echo "-L --max-redirs ${CCDC_HTTP_MAX_REDIRS}"
  else
    echo ""
  fi
}

ccdc_http__csv_safe() {
  # Remove newlines/commas/tabs; collapse whitespace (best-effort).
  local s="${1:-}"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  s="${s//$'\t'/ }"
  s="${s//,/ }"

  if _ccdc_http__need_cmd sed; then
    echo "$s" | sed 's/[[:space:]]\+/ /g; s/^ *//; s/ *$//'
  else
    echo "$s"
  fi
}

ccdc_http__is_html_ctype() {
  local ctype="${1:-}"
  echo "$ctype" | grep -qiE 'text/html|application/xhtml\+xml'
}

ccdc_http__looks_like_html() {
  local body="${1:-}"
  echo "$body" | grep -qiE '<(html|title)\b'
}

ccdc_http__extract_header() {
  local hdrs="${1:-}"
  local name="${2:-}"
  [[ -n "$hdrs" && -n "$name" ]] || { echo ""; return 0; }

  if ! _ccdc_http__need_cmd awk; then
    _ccdc_http__warn "awk missing; cannot extract headers"
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

ccdc_http__extract_last_status() {
  local hdrs="${1:-}"
  [[ -n "$hdrs" ]] || { echo "?"; return 0; }

  if ! _ccdc_http__need_cmd awk; then
    _ccdc_http__warn "awk missing; cannot parse HTTP status"
    echo "?"
    return 1
  fi

  echo "$hdrs" | awk 'BEGIN{code="?"} toupper($0) ~ /^HTTP\// {code=$2} END{print code}'
}

ccdc_http__url_for_ip_port() {
  # Usage: ccdc_http__url_for_ip_port "http" "172.25.21.10" "80" "/admin"
  local scheme="${1:-http}"
  local ip="${2:-}"
  local port="${3:-80}"
  local path="${4:-/}"
  echo "${scheme}://${ip}:${port}${path}"
}

ccdc_http__url_for_team_host() {
  # Optional convenience helper.
  # Requires ccdc_net_scheme.sh to be sourced by the CALLER (not by this lib).
  #
  # Usage:
  #   url="$(ccdc_http__url_for_team_host "$TEAM" 10 "https" 443 "/")"
  #
  # If ccdc_net__public_host is not available, returns 1.
  local team="${1:-}"
  local host="${2:-}"
  local scheme="${3:-http}"
  local port="${4:-80}"
  local path="${5:-/}"

  if ! declare -F ccdc_net__public_host >/dev/null 2>&1; then
    _ccdc_http__warn "ccdc_net__public_host not found (source ccdc_net_scheme.sh in caller)."
    return 1
  fi

  local ip
  ip="$(ccdc_net__public_host "$team" "$host" 2>/dev/null || true)"
  [[ -n "$ip" ]] || return 1
  echo "${scheme}://${ip}:${port}${path}"
  return 0
}

ccdc_http__curl_headers() {
  local url="${1:-}"
  [[ -n "$url" ]] || return 1
  _ccdc_http__need_cmd curl || { _ccdc_http__warn "curl missing"; return 1; }

  # shellcheck disable=SC2206
  local follow_args=($(_ccdc_http__follow_args))

  curl -sS \
    --connect-timeout "${CCDC_HTTP_CONNECT_TIMEOUT}" \
    --max-time "${CCDC_HTTP_TIMEOUT_SECS}" \
    -A "${CCDC_HTTP_UA}" \
    "${follow_args[@]}" \
    -D - \
    -o /dev/null \
    "$url" 2>/dev/null
}

ccdc_http__curl_tiny_get() {
  local url="${1:-}"
  [[ -n "$url" ]] || return 1
  _ccdc_http__need_cmd curl || { _ccdc_http__warn "curl missing"; return 1; }

  # shellcheck disable=SC2206
  local follow_args=($(_ccdc_http__follow_args))

  curl -sS \
    --connect-timeout "${CCDC_HTTP_CONNECT_TIMEOUT}" \
    --max-time "${CCDC_HTTP_TIMEOUT_SECS}" \
    -A "${CCDC_HTTP_UA}" \
    "${follow_args[@]}" \
    --range "0-${CCDC_HTTP_TITLE_BYTES}" \
    "$url" 2>/dev/null || true
}

ccdc_http__extract_title() {
  _ccdc_http__need_cmd tr || return 1
  _ccdc_http__need_cmd head || return 1
  _ccdc_http__need_cmd sed || return 1

  tr '\r\n' ' ' \
    | sed -n 's/.*<title[^>]*>\(.*\)<\/title>.*/\1/ip' \
    | head -n 1 \
    | sed 's/[[:space:]]\+/ /g; s/^ *//; s/ *$//'
}

ccdc_http__title_if_html() {
  local url="${1:-}"
  local ctype="${2:-}"
  [[ -n "$url" ]] || { echo ""; return 0; }

  if ccdc_http__is_html_ctype "$ctype"; then
    ccdc_http__curl_tiny_get "$url" | ccdc_http__extract_title
    return 0
  fi

  if [[ -z "$ctype" ]]; then
    local body
    body="$(ccdc_http__curl_tiny_get "$url")"
    if ccdc_http__looks_like_html "$body"; then
      echo "$body" | ccdc_http__extract_title
      return 0
    fi
  fi

  echo ""
  return 0
}

ccdc_http__normalize_url() {
  local s="${1:-}"
  [[ -n "$s" ]] || { echo ""; return 0; }
  if [[ "$s" =~ ^https?:// ]]; then
    echo "$s"
  else
    echo "http://${s}"
  fi
}

ccdc_http__guess_scheme() {
  local ip="${1:-}"
  [[ -n "$ip" ]] || { echo ""; return 0; }

  if ccdc_http__curl_headers "https://${ip}:443/" >/dev/null 2>&1; then
    echo "https"
    return 0
  fi
  if ccdc_http__curl_headers "http://${ip}:80/" >/dev/null 2>&1; then
    echo "http"
    return 0
  fi
  echo ""
  return 0
}

ccdc_http__fingerprint_hints() {
  if ! _ccdc_http__need_cmd grep; then
    _ccdc_http__warn "grep missing; cannot fingerprint hints"
    echo ""
    return 1
  fi

  local tags
  tags="$(
    tr '\r\n' ' ' 2>/dev/null \
      | grep -Eoi 'opencart|wordpress|drupal|joomla|splunk|roundcube|squirrelmail|zimbra|owa|grafana|prometheus|jenkins|tomcat|phpmyadmin|webmin|cockpit|proxmox|cpanel|webmail|login|admin|dashboard' \
      | head -n 25 2>/dev/null \
      | tr '\n' ' ' 2>/dev/null
  )"

  tags="$(ccdc_http__csv_safe "$tags")"
  if _ccdc_http__need_cmd awk; then
    echo "$tags" | awk '{for(i=1;i<=NF;i++){if(!seen[$i]++){out=out $i " "}}} END{gsub(/[[:space:]]+$/,"",out); print out}'
  else
    echo "$tags"
  fi
}

ccdc_http__security_header_gaps() {
  # Report common defensive headers that are absent. This is triage-only, not a
  # vulnerability verdict; operators should verify context before scoring.
  local hdrs="${1:-}"
  local scheme="${2:-}"
  [[ -n "$hdrs" ]] || { echo ""; return 0; }

  local gaps=()
  [[ -n "$(ccdc_http__extract_header "$hdrs" "Content-Security-Policy" 2>/dev/null || true)" ]] || gaps+=("missing_csp")
  [[ -n "$(ccdc_http__extract_header "$hdrs" "X-Frame-Options" 2>/dev/null || true)" ]] || gaps+=("missing_x_frame_options")
  [[ -n "$(ccdc_http__extract_header "$hdrs" "X-Content-Type-Options" 2>/dev/null || true)" ]] || gaps+=("missing_x_content_type_options")
  [[ -n "$(ccdc_http__extract_header "$hdrs" "Referrer-Policy" 2>/dev/null || true)" ]] || gaps+=("missing_referrer_policy")

  # HSTS is meaningful for HTTPS responses only.
  if [[ "$scheme" == "https" ]]; then
    [[ -n "$(ccdc_http__extract_header "$hdrs" "Strict-Transport-Security" 2>/dev/null || true)" ]] || gaps+=("missing_hsts")
  fi

  local out
  out="${gaps[*]}"
  ccdc_http__csv_safe "$out"
}

ccdc_http__tls_cn() {
  local ip="${1:-}"
  [[ -n "$ip" ]] || { echo ""; return 0; }

  if ! _ccdc_http__need_cmd openssl; then
    echo ""
    return 0
  fi

  if _ccdc_http__need_cmd timeout; then
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

ccdc_http__fetch_fields() {
  local url="${1:-}"
  [[ -n "$url" ]] || { echo "|||||"; return 1; }

  local hdrs status server xpb ctype loc auth
  hdrs="$(ccdc_http__curl_headers "$url" 2>/dev/null || true)"
  [[ -n "$hdrs" ]] || { echo "|||||"; return 1; }

  status="$(ccdc_http__extract_last_status "$hdrs" || echo "?")"
  server="$(ccdc_http__extract_header "$hdrs" "Server" || true)"
  xpb="$(ccdc_http__extract_header "$hdrs" "X-Powered-By" || true)"
  ctype="$(ccdc_http__extract_header "$hdrs" "Content-Type" || true)"
  loc="$(ccdc_http__extract_header "$hdrs" "Location" || true)"
  auth="$(ccdc_http__extract_header "$hdrs" "WWW-Authenticate" || true)"

  echo "${status}|${server}|${xpb}|${ctype}|${loc}|${auth}"
}
