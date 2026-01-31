#!/usr/bin/env bash
# lib/ccdc_utils.sh
set -euo pipefail

# ============================================================
# Phase 1 Utility Library (team/net/files)
# Version : 0.2.0
#
# Notes:
# - Does not exit by default; returns non-zero.
# - Uses ccdc__warn/ccdc__log/ccdc__log_kv if available.
# - If ccdc_net_scheme.sh is sourced, prefers its functions for subnet math.
# ============================================================

_ccdc_utils__warn() {
  local msg="$*"
  if declare -F ccdc__warn >/dev/null 2>&1; then
    ccdc__warn "$msg"
  else
    echo "WARN: $msg" >&2
  fi
}

_ccdc_utils__log() {
  local msg="$*"
  if declare -F ccdc__log >/dev/null 2>&1; then
    ccdc__log "$msg"
  else
    echo "$msg"
  fi
}

_ccdc_utils__log_kv() {
  local k="${1:-}" v="${2:-}"
  if declare -F ccdc__log_kv >/dev/null 2>&1; then
    ccdc__log_kv "$k" "$v"
  else
    _ccdc_utils__log "[*] ${k}: ${v}"
  fi
}

ccdc__usage_team() {
  local script_name="${1:-script.sh}"
  echo "Usage:"
  echo "  ./${script_name}"
  echo "  ./${script_name} <TEAM_NUMBER>"
  echo
  echo "Example:"
  echo "  ./${script_name} 21"
  echo
  echo "Tip:"
  echo "  Many Phase 1 scripts save the last team to output/team.txt."
}

ccdc__is_number() {
  local s="${1:-}"
  [[ "$s" =~ ^[0-9]+$ ]]
}

CCDC_BLOCKED_TEAMS="${CCDC_BLOCKED_TEAMS:-19}"
CCDC_RULES_LOADED="${CCDC_RULES_LOADED:-0}"

ccdc__load_rules() {
  # Load repo-wide rules (blocked teams, etc.). Safe to call multiple times.
  [[ "${CCDC_RULES_LOADED}" == "1" ]] && return 0

  local rules_file="${CCDC_RULES_FILE:-}"
  if [[ -z "$rules_file" ]]; then
    if [[ -n "${CCDC_BASE_DIR:-}" ]]; then
      rules_file="${CCDC_BASE_DIR}/../Config/ccdc_rules.conf"
    else
      local lib_dir
      lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"
      rules_file="${lib_dir}/../../Config/ccdc_rules.conf"
    fi
  fi

  if [[ -f "$rules_file" ]]; then
    # shellcheck disable=SC1090
    source "$rules_file" || true
  fi
  CCDC_RULES_LOADED=1
  return 0
}

ccdc__is_blocked_team() {
  local team="${1:-}"
  ccdc__load_rules || true
  local t
  for t in ${CCDC_BLOCKED_TEAMS}; do
    if [[ "$t" == "$team" ]]; then
      return 0
    fi
  done
  return 1
}

ccdc__validate_team() {
  local team="${1:-}"
  [[ -n "$team" ]] || return 1
  [[ "$team" =~ ^[0-9]{1,3}$ ]] || return 1
  if ccdc__is_blocked_team "$team"; then
    _ccdc_utils__warn "Team ${team} is reserved for baseline connectivity; do not target."
    return 1
  fi
  (( team >= 0 && team <= 255 )) || return 1
  return 0
}

ccdc__validate_host_octet() {
  local host="${1:-}"
  [[ "$host" =~ ^[0-9]{1,3}$ ]] || return 1
  (( host >= 0 && host <= 255 )) || return 1
  return 0
}

ccdc__validate_port() {
  local port="${1:-}"
  [[ "$port" =~ ^[0-9]{1,5}$ ]] || return 1
  (( port >= 1 && port <= 65535 )) || return 1
  return 0
}

ccdc__write_file_safe() {
  # Writes content to file. If exists, writes <file>.new to avoid clobbering.
  local path="${1:-}"
  local content="${2:-}"
  [[ -n "$path" ]] || return 1

  local out_path="$path"
  if [[ -f "$path" ]]; then
    out_path="${path}.new"
    _ccdc_utils__warn "File exists: $path -> writing: $out_path"
  fi

  printf "%s\n" "$content" > "$out_path" 2>/dev/null || return 1
  _ccdc_utils__log "[*] Wrote: $out_path"
  return 0
}

ccdc__write_file_overwrite() {
  # Writes content to file, overwriting always (useful for generated outputs)
  local path="${1:-}"
  local content="${2:-}"
  [[ -n "$path" ]] || return 1
  printf "%s\n" "$content" > "$path" 2>/dev/null || return 1
  _ccdc_utils__log "[*] Wrote (overwrite): $path"
  return 0
}

ccdc__append_line() {
  # Appends a single line to a file (creates file if missing)
  local path="${1:-}"
  local line="${2:-}"
  [[ -n "$path" ]] || return 1
  printf "%s\n" "$line" >> "$path" 2>/dev/null || return 1
  return 0
}

ccdc__save_last_team() {
  local team="${1:-}"
  ccdc__validate_team "$team" || return 1

  # Ensure output dir exists
  if [[ -z "${CCDC_OUT_DIR:-}" ]]; then
    if declare -F ccdc__init_env >/dev/null 2>&1; then
      ccdc__init_env || return 1
    else
      return 1
    fi
  fi

  echo "$team" > "${CCDC_OUT_DIR}/team.txt" 2>/dev/null || return 1
  _ccdc_utils__log_kv "Saved team" "${CCDC_OUT_DIR}/team.txt"
  return 0
}

ccdc__load_last_team() {
  # Returns saved team number or empty.
  if [[ -z "${CCDC_OUT_DIR:-}" ]]; then
    if declare -F ccdc__init_env >/dev/null 2>&1; then
      ccdc__init_env || { echo ""; return 0; }
    else
      echo ""
      return 0
    fi
  fi

  local f="${CCDC_OUT_DIR}/team.txt"
  [[ -f "$f" ]] || { echo ""; return 0; }
  cat "$f" 2>/dev/null || echo ""
}

ccdc__parse_team_or_last() {
  # Usage: TEAM="$(ccdc__parse_team_or_last "$1")" || { usage; exit 1; }
  local team="${1:-}"

  if [[ -n "$team" ]]; then
    ccdc__validate_team "$team" || return 1
    echo "$team"
    return 0
  fi

  local last
  last="$(ccdc__load_last_team)"
  if [[ -n "$last" ]] && ccdc__validate_team "$last"; then
    echo "$last"
    return 0
  fi

  return 1
}

# --- Network helpers ---
# Prefer ccdc_net_scheme.sh if loaded; otherwise fall back to the original formula.
ccdc__target_net() {
  local team="${1:-}"
  ccdc__validate_team "$team" || return 1

  if declare -F ccdc_net__public_subnet >/dev/null 2>&1; then
    ccdc_net__public_subnet "$team"
    return 0
  fi

  # fallback: original assumption (team->team+20)
  local oct=$((team + 20))
  echo "172.25.${oct}.0/24"
}

ccdc__ip_for_hostnum() {
  local team="${1:-}"
  local host="${2:-}"
  ccdc__validate_team "$team" || return 1
  ccdc__validate_host_octet "$host" || return 1

  if declare -F ccdc_net__public_host >/dev/null 2>&1; then
    ccdc_net__public_host "$team" "$host"
    return 0
  fi

  local oct=$((team + 20))
  echo "172.25.${oct}.${host}"
}
