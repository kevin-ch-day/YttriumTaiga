#!/usr/bin/env bash
# lib/ccdc_runtime.sh
set -euo pipefail

# ============================================================
# Phase 1 Runtime/Logging Library
# Version : 0.2.0
#
# Goals:
# - Establish Phase base dirs (logs/, output/)
# - Provide consistent logging + sections
# - Avoid exiting from inside lib by default
#
# Caller options:
# - CCDC_FATAL=1 -> ccdc__die will exit
# - CCDC_QUIET=1 -> suppress stdout (still logs)
# ============================================================

: "${CCDC_FATAL:=0}"
: "${CCDC_QUIET:=0}"
: "${CCDC_UMASK:=002}"

: "${CCDC_BASE_DIR:=}"
: "${CCDC_LOG_DIR:=}"
: "${CCDC_OUT_DIR_BASE:=}"
: "${CCDC_OUT_DIR:=}"
: "${CCDC_LOG_FILE:=}"
: "${CCDC_PHASE_NAME:=}"   # optional label for logs

ccdc__now() { date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date; }

ccdc__phase_base_dir() {
  # base dir one level above lib/
  local lib_dir=""
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || return 1
  (cd "${lib_dir}/.." && pwd 2>/dev/null) || return 1
}

ccdc__ensure_phase_dirs() {
  local base_dir="${1:-}"
  [[ -n "$base_dir" ]] || return 1
  mkdir -p "${base_dir}/logs" "${base_dir}/output" 2>/dev/null || return 1
  return 0
}

ccdc__fix_ownership() {
  # Ensure artifacts are owned by the invoking user when run via sudo.
  # This avoids root-owned logs/outputs that operators can't edit.
  local target_dir="${1:-}"
  [[ -n "$target_dir" ]] || return 1
  [[ "${EUID:-$(id -u 2>/dev/null || echo 0)}" -eq 0 ]] || return 0
  [[ -n "${SUDO_USER:-}" ]] || return 0
  chown -R "${SUDO_USER}:${SUDO_USER}" "$target_dir" 2>/dev/null || true
  return 0
}

ccdc__init_env() {
  # Initializes CCDC_BASE_DIR/LOG_DIR/OUT_DIR only.
  CCDC_BASE_DIR="$(ccdc__phase_base_dir)" || return 1
  CCDC_LOG_DIR="${CCDC_BASE_DIR}/logs"
  CCDC_OUT_DIR_BASE="${CCDC_BASE_DIR}/output"
  CCDC_OUT_DIR="${CCDC_OUT_DIR_BASE}"
  ccdc__ensure_phase_dirs "$CCDC_BASE_DIR" || return 1
  umask "${CCDC_UMASK}" 2>/dev/null || true
  ccdc__fix_ownership "$CCDC_BASE_DIR"

  # Default phase name from folder if not set
  if [[ -z "${CCDC_PHASE_NAME:-}" ]]; then
    CCDC_PHASE_NAME="$(basename "$CCDC_BASE_DIR" 2>/dev/null || echo "phase")"
  fi
  return 0
}

ccdc__init_run() {
  # Usage: ccdc__init_run "phase1_service_inventory"
  local run_name="${1:-run}"
  ccdc__init_env || return 1

  CCDC_LOG_FILE="${CCDC_LOG_DIR}/${run_name}.log"
  : > "$CCDC_LOG_FILE" 2>/dev/null || return 1

  # Run header (helps later when reading logs)
  ccdc__log "[*] Phase: ${CCDC_PHASE_NAME}"
  ccdc__log "[*] Run:   ${run_name}"
  ccdc__log "[*] Time:  $(ccdc__now)"
  ccdc__log "[*] Base:  ${CCDC_BASE_DIR}"
  ccdc__log "[*] User:  $(whoami 2>/dev/null || echo unknown)"
  ccdc__log "[*] Host:  $(hostname 2>/dev/null || echo unknown)"
  return 0
}

ccdc__log() {
  local msg="$*"
  if [[ "${CCDC_QUIET}" != "1" ]]; then
    echo "$msg"
  fi
  if [[ -n "${CCDC_LOG_FILE:-}" ]]; then
    echo "$msg" >> "$CCDC_LOG_FILE" 2>/dev/null || true
  fi
}

ccdc__log_kv() {
  # Consistent key/value logging
  # Usage: ccdc__log_kv "Team" "21"
  local k="${1:-}"
  local v="${2:-}"
  ccdc__log "$(printf "[*] %-12s %s" "${k}:" "$v")"
}

ccdc__section() {
  ccdc__log ""
  ccdc__log "============================================================"
  ccdc__log "$*"
  ccdc__log "============================================================"
}

ccdc__warn() { ccdc__log "WARN: $*"; return 0; }

ccdc__die() {
  ccdc__log "ERROR: $*"
  if [[ "${CCDC_FATAL}" == "1" ]]; then
    exit 1
  fi
  return 1
}

ccdc__need_cmd() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 1
  command -v "$cmd" >/dev/null 2>&1 || ccdc__die "Missing required command: $cmd"
}

ccdc__require_cmds() {
  local missing=0 cmd=""
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      ccdc__warn "Missing required command: $cmd"
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    ccdc__warn "One or more required commands are missing."
    return 1
  fi
  return 0
}

ccdc__file_exists() {
  local p="${1:-}"
  [[ -n "$p" && -f "$p" ]]
}

ccdc__dir_exists() {
  local p="${1:-}"
  [[ -n "$p" && -d "$p" ]]
}

ccdc__open_viewer() {
  # Best-effort view a file: less (preferred) else cat
  local path="${1:-}"
  [[ -n "$path" ]] || return 1
  [[ -f "$path" ]] || { ccdc__warn "File not found: $path"; return 1; }

  if command -v less >/dev/null 2>&1; then
    less -R "$path" || true
  else
    cat "$path" || true
  fi
  return 0
}

ccdc__safe_source() {
  # Safe wrapper to source a library file.
  local path="${1:-}"
  [[ -n "$path" ]] || return 1

  if [[ -f "$path" ]]; then
    # shellcheck disable=SC1090
    if source "$path"; then
      return 0
    fi
    ccdc__warn "Failed sourcing lib (syntax/runtime error): $path (continuing)"
    return 1
  fi

  ccdc__warn "Missing lib file: $path (continuing)"
  return 1
}
