#!/usr/bin/env bash
# lib/phase2_lib_utils.sh
set -euo pipefail

# ============================================================
# Phase 2 Utility Library (team/net/files)
# Version : 0.1.0
#
# Notes:
# - Phase 2 only. No cross-phase assumptions.
# - Does not exit by default; returns non-zero on failure.
# - If phase2_lib_runtime.sh is loaded, prefers:
#     PHASE2_OUT_DIR, PHASE2_LOG_FILE
# - If phase2_lib_net_scheme.sh is loaded, prefers ccdc_net__* helpers.
# ============================================================

# -----------------------------
# Internal logging shims
# -----------------------------
_phase2_utils__warn() {
  local msg="$*"
  if declare -F phase2_warn >/dev/null 2>&1; then
    phase2_warn "$msg"
  elif declare -F ccdc__warn >/dev/null 2>&1; then
    ccdc__warn "$msg"
  else
    echo "WARN: $msg" >&2
  fi
}

_phase2_utils__log() {
  local msg="$*"
  if declare -F phase2_log >/dev/null 2>&1; then
    phase2_log "$msg"
  elif declare -F ccdc__log >/dev/null 2>&1; then
    ccdc__log "$msg"
  else
    echo "$msg"
  fi
}

_phase2_utils__log_kv() {
  local k="${1:-}" v="${2:-}"
  if declare -F phase2_log_kv >/dev/null 2>&1; then
    phase2_log_kv "$k" "$v"
  elif declare -F ccdc__log_kv >/dev/null 2>&1; then
    ccdc__log_kv "$k" "$v"
  else
    _phase2_utils__log "[*] ${k}: ${v}"
  fi
}

# -----------------------------
# Usage / validation helpers
# -----------------------------
phase2_usage_team() {
  local script_name="${1:-script.sh}"
  echo "Usage:"
  echo "  ./${script_name}"
  echo "  ./${script_name} <TEAM_NUMBER>"
  echo
  echo "Example:"
  echo "  ./${script_name} 21"
  echo
  echo "Tip:"
  echo "  Phase 2 scripts can save the last team to output/team.txt."
}

phase2_is_number() {
  local s="${1:-}"
  [[ "$s" =~ ^[0-9]+$ ]]
}

PHASE2_BLOCKED_TEAMS="${PHASE2_BLOCKED_TEAMS:-19}"
PHASE2_RULES_LOADED="${PHASE2_RULES_LOADED:-0}"

phase2_load_rules() {
  [[ "${PHASE2_RULES_LOADED}" == "1" ]] && return 0

  local rules_file="${PHASE2_RULES_FILE:-}"
  if [[ -z "$rules_file" ]]; then
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"
    rules_file="${lib_dir}/../../config/ccdc_rules.conf"
  fi

  if [[ -f "$rules_file" ]]; then
    # shellcheck disable=SC1090
    source "$rules_file" || true
    # Allow shared variable name
    if [[ -n "${CCDC_BLOCKED_TEAMS:-}" ]]; then
      PHASE2_BLOCKED_TEAMS="${CCDC_BLOCKED_TEAMS}"
    fi
  fi
  PHASE2_RULES_LOADED=1
  return 0
}

phase2_is_blocked_team() {
  local team="${1:-}"
  phase2_load_rules || true
  local t
  for t in ${PHASE2_BLOCKED_TEAMS}; do
    if [[ "$t" == "$team" ]]; then
      return 0
    fi
  done
  return 1
}

phase2_validate_team() {
  local team="${1:-}"
  [[ -n "$team" ]] || return 1
  [[ "$team" =~ ^[0-9]{1,3}$ ]] || return 1
  if phase2_is_blocked_team "$team"; then
    _phase2_utils__warn "Team ${team} is reserved for baseline connectivity; do not target."
    return 1
  fi
  (( team >= 0 && team <= 255 )) || return 1
  return 0
}

phase2_validate_host_octet() {
  local host="${1:-}"
  [[ "$host" =~ ^[0-9]{1,3}$ ]] || return 1
  (( host >= 0 && host <= 255 )) || return 1
  return 0
}

phase2_validate_port() {
  local port="${1:-}"
  [[ "$port" =~ ^[0-9]{1,5}$ ]] || return 1
  (( port >= 1 && port <= 65535 )) || return 1
  return 0
}

# -----------------------------
# File helpers
# -----------------------------
phase2_write_file_safe() {
  # Writes content to file. If exists, writes <file>.new to avoid clobbering.
  local path="${1:-}"
  local content="${2:-}"
  [[ -n "$path" ]] || return 1

  local out_path="$path"
  if [[ -f "$path" ]]; then
    out_path="${path}.new"
    _phase2_utils__warn "File exists: $path -> writing: $out_path"
  fi

  printf "%s\n" "$content" > "$out_path" 2>/dev/null || return 1
  _phase2_utils__log "[*] Wrote: $out_path"
  return 0
}

phase2_write_file_overwrite() {
  # Writes content to file, overwriting always (useful for generated outputs)
  local path="${1:-}"
  local content="${2:-}"
  [[ -n "$path" ]] || return 1
  printf "%s\n" "$content" > "$path" 2>/dev/null || return 1
  _phase2_utils__log "[*] Wrote (overwrite): $path"
  return 0
}

phase2_append_line() {
  # Appends a single line to a file (creates file if missing)
  local path="${1:-}"
  local line="${2:-}"
  [[ -n "$path" ]] || return 1
  printf "%s\n" "$line" >> "$path" 2>/dev/null || return 1
  return 0
}

# -----------------------------
# Output dir resolution (Phase 2 local)
# -----------------------------
phase2__resolve_out_dir() {
  # Prefer runtime-exported PHASE2_OUT_DIR if present.
  if [[ -n "${PHASE2_OUT_DIR:-}" ]]; then
    echo "$PHASE2_OUT_DIR"
    return 0
  fi

  # If meta is sourced, prefer PHASE_OUT_DIR name (relative folder), else "output"
  local out_name="${PHASE_OUT_DIR:-output}"

  # Attempt to infer phase root from LIB directory if available
  # If this utils file is in <phase>/lib/, then base is one level up.
  local this_dir
  this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "$(cd "$this_dir/.." && pwd)/${out_name}"
}

phase2_save_last_team() {
  local team="${1:-}"
  phase2_validate_team "$team" || return 1

  local out_dir
  out_dir="$(phase2__resolve_out_dir)" || return 1
  mkdir -p "$out_dir" 2>/dev/null || return 1

  echo "$team" > "${out_dir}/team.txt" 2>/dev/null || return 1
  if [[ "${PHASE2_BRIEF:-0}" != "1" ]]; then
    _phase2_utils__log_kv "Saved team" "${out_dir}/team.txt"
  fi
  return 0
}

phase2_load_last_team() {
  # Returns saved team number or empty.
  local out_dir
  out_dir="$(phase2__resolve_out_dir)" || { echo ""; return 0; }

  local f="${out_dir}/team.txt"
  [[ -f "$f" ]] || { echo ""; return 0; }
  cat "$f" 2>/dev/null || echo ""
}

phase2_parse_team_or_last() {
  # Usage: TEAM="$(phase2_parse_team_or_last "$1")" || { usage; exit 1; }
  local team="${1:-}"

  if [[ -n "$team" ]]; then
    phase2_validate_team "$team" || return 1
    echo "$team"
    return 0
  fi

  local last
  last="$(phase2_load_last_team)"
  if [[ -n "$last" ]] && phase2_validate_team "$last"; then
    echo "$last"
    return 0
  fi

  return 1
}

# -----------------------------
# Network helpers (Phase 2)
# Prefer ccdc_net_scheme functions if loaded; fallback to basic formula.
# -----------------------------
phase2_target_net() {
  local team="${1:-}"
  phase2_validate_team "$team" || return 1

  if declare -F ccdc_net__public_subnet >/dev/null 2>&1; then
    ccdc_net__public_subnet "$team"
    return 0
  fi

  # Fallback assumption: team -> team + 20
  local oct=$((team + 20))
  echo "172.25.${oct}.0/24"
}

phase2_ip_for_hostnum() {
  local team="${1:-}"
  local host="${2:-}"
  phase2_validate_team "$team" || return 1
  phase2_validate_host_octet "$host" || return 1

  if declare -F ccdc_net__public_host >/dev/null 2>&1; then
    ccdc_net__public_host "$team" "$host"
    return 0
  fi

  local oct=$((team + 20))
  echo "172.25.${oct}.${host}"
}
