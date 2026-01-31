#!/usr/bin/env bash
# lib/phase2_lib_runtime.sh
set -euo pipefail

# ============================================================
# Phase 2 Runtime/Logging Library
# Version : 0.1.0
#
# Goals (Phase 2 only):
# - Establish Phase 2 base dirs (logs/, output/)
# - Provide consistent logging + sections
# - Avoid exiting from inside lib by default
#
# Caller options:
# - PHASE2_FATAL=1 -> phase2_die will exit
# - PHASE2_QUIET=1 -> suppress stdout (still logs)
#
# Meta integration:
# - If phase2_lib_meta.sh is sourced, it can define:
#   PHASE_ID, PHASE_NAME, PHASE_VERSION,
#   PHASE_LOG_DIR, PHASE_OUT_DIR,
#   LOG_FILE_DEFAULT, LOG_MODE_DEFAULT, VERBOSE_DEFAULT
# ============================================================

: "${PHASE2_FATAL:=0}"
: "${PHASE2_QUIET:=0}"
: "${PHASE2_BRIEF:=0}"
: "${PHASE2_UMASK:=002}"

: "${PHASE2_BASE_DIR:=}"
: "${PHASE2_LOG_DIR:=}"
: "${PHASE2_OUT_DIR:=}"
: "${PHASE2_LOG_FILE:=}"

PHASE2_TIMEZONE="${PHASE2_TIMEZONE:-America/Chicago}"
PHASE2_TIME_FORMAT="${PHASE2_TIME_FORMAT:-%Y-%m-%d %H:%M:%S}"
PHASE2_TIME_RULES_LOADED="${PHASE2_TIME_RULES_LOADED:-0}"

phase2_load_time_rules() {
  [[ "${PHASE2_TIME_RULES_LOADED}" == "1" ]] && return 0
  local rules_file="${PHASE2_RULES_FILE:-}"
  if [[ -z "$rules_file" ]]; then
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"
    rules_file="${lib_dir}/../../config/ccdc_rules.conf"
  fi
  if [[ -f "$rules_file" ]]; then
    # shellcheck disable=SC1090
    source "$rules_file" || true
    if [[ -n "${CCDC_TIMEZONE:-}" ]]; then
      PHASE2_TIMEZONE="${CCDC_TIMEZONE}"
    fi
    if [[ -n "${CCDC_TIME_FORMAT:-}" ]]; then
      PHASE2_TIME_FORMAT="${CCDC_TIME_FORMAT}"
    fi
  fi
  PHASE2_TIME_RULES_LOADED=1
  return 0
}

phase2_now() {
  phase2_load_time_rules || true
  TZ="${PHASE2_TIMEZONE}" date "+${PHASE2_TIME_FORMAT}" 2>/dev/null || date
}

phase2__apply_meta_defaults() {
  # Identity defaults (only if not provided by meta)
  : "${PHASE_ID:=phase2}"
  : "${PHASE_NAME:=Phase 2 (Privilege Expansion)}"
  : "${PHASE_VERSION:=0.1.0}"

  # Directory defaults (meta can override)
  : "${PHASE_LOG_DIR:=logs}"
  : "${PHASE_OUT_DIR:=output}"

  # Logging defaults (meta can override)
  : "${LOG_FILE_DEFAULT:=phase2.log}"
  : "${LOG_MODE_DEFAULT:=append}"  # append|overwrite
  : "${VERBOSE_DEFAULT:=1}"
}

phase2_phase_base_dir() {
  # base dir one level above lib/
  local lib_dir=""
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || return 1
  (cd "${lib_dir}/.." && pwd 2>/dev/null) || return 1
}

phase2_ensure_phase_dirs() {
  local base_dir="${1:-}"
  [[ -n "$base_dir" ]] || return 1

  # Use meta-driven dir names
  phase2__apply_meta_defaults
  mkdir -p "${base_dir}/${PHASE_LOG_DIR}" "${base_dir}/${PHASE_OUT_DIR}" 2>/dev/null || return 1
  return 0
}

phase2_fix_ownership() {
  # Ensure artifacts are owned by the invoking user when run via sudo.
  local target_dir="${1:-}"
  [[ -n "$target_dir" ]] || return 1
  [[ "${EUID:-$(id -u 2>/dev/null || echo 0)}" -eq 0 ]] || return 0
  [[ -n "${SUDO_USER:-}" ]] || return 0
  chown -R "${SUDO_USER}:${SUDO_USER}" "$target_dir" 2>/dev/null || true
  return 0
}

phase2_init_env() {
  # Initializes PHASE2_BASE_DIR/LOG_DIR/OUT_DIR only.
  phase2__apply_meta_defaults

  PHASE2_BASE_DIR="$(phase2_phase_base_dir)" || return 1
  PHASE2_LOG_DIR="${PHASE2_BASE_DIR}/${PHASE_LOG_DIR}"
  if [[ -z "${PHASE2_OUT_DIR:-}" ]]; then
    PHASE2_OUT_DIR="${PHASE2_BASE_DIR}/${PHASE_OUT_DIR}"
  fi

  phase2_ensure_phase_dirs "$PHASE2_BASE_DIR" || return 1
  umask "${PHASE2_UMASK}" 2>/dev/null || true
  phase2_fix_ownership "$PHASE2_BASE_DIR"
  return 0
}

phase2_init_run() {
  # Usage:
  #   phase2_init_run "phase2_whatever"
  # If run_name is omitted, uses LOG_FILE_DEFAULT.
  local run_name="${1:-}"

  phase2_init_env || return 1

  # Determine log file path (stable by default)
  if [[ -n "${run_name}" ]]; then
    PHASE2_LOG_FILE="${PHASE2_LOG_DIR}/${run_name}.log"
  else
    PHASE2_LOG_FILE="${PHASE2_LOG_DIR}/${LOG_FILE_DEFAULT}"
  fi

  # Log mode behavior
  if [[ "${LOG_MODE_DEFAULT}" == "overwrite" ]]; then
    : > "$PHASE2_LOG_FILE" 2>/dev/null || return 1
  else
    touch "$PHASE2_LOG_FILE" 2>/dev/null || return 1
  fi

  # Run header (helps later when reading logs)
  if [[ "${PHASE2_BRIEF}" == "1" ]]; then
    {
      echo "[*] Phase: ${PHASE_NAME} v${PHASE_VERSION} (${PHASE_ID})"
      echo "[*] Run:   ${run_name:-${LOG_FILE_DEFAULT}}"
      echo "[*] Time:  $(phase2_now)"
      echo "[*] Base:  ${PHASE2_BASE_DIR}"
      echo "[*] User:  $(whoami 2>/dev/null || echo unknown)"
      echo "[*] Host:  $(hostname 2>/dev/null || echo unknown)"
    } >> "$PHASE2_LOG_FILE" 2>/dev/null || true
  else
    phase2_log "[*] Phase: ${PHASE_NAME} v${PHASE_VERSION} (${PHASE_ID})"
    phase2_log "[*] Run:   ${run_name:-${LOG_FILE_DEFAULT}}"
    phase2_log "[*] Time:  $(phase2_now)"
    phase2_log "[*] Base:  ${PHASE2_BASE_DIR}"
    phase2_log "[*] User:  $(whoami 2>/dev/null || echo unknown)"
    phase2_log "[*] Host:  $(hostname 2>/dev/null || echo unknown)"
  fi
  return 0
}

phase2_log() {
  local msg="$*"

  # Console
  if [[ "${PHASE2_QUIET}" != "1" ]]; then
    echo "$msg"
  fi

  # File
  if [[ -n "${PHASE2_LOG_FILE:-}" ]]; then
    echo "$msg" >> "$PHASE2_LOG_FILE" 2>/dev/null || true
  fi
}

phase2_log_kv() {
  # Consistent key/value logging
  # Usage: phase2_log_kv "Team" "21"
  local k="${1:-}"
  local v="${2:-}"
  phase2_log "$(printf "[*] %-12s %s" "${k}:" "$v")"
}

phase2_section() {
  phase2_log ""
  phase2_log "============================================================"
  phase2_log "$*"
  phase2_log "============================================================"
}

phase2_warn() { phase2_log "WARN: $*"; return 0; }

phase2_die() {
  phase2_log "ERROR: $*"
  if [[ "${PHASE2_FATAL}" == "1" ]]; then
    exit 1
  fi
  return 1
}

phase2_need_cmd() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 1
  command -v "$cmd" >/dev/null 2>&1 || phase2_die "Missing required command: $cmd"
}

phase2_require_cmds() {
  local missing=0 cmd=""
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      phase2_warn "Missing required command: $cmd"
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    phase2_warn "One or more required commands are missing."
    return 1
  fi
  return 0
}

phase2_file_exists() {
  local p="${1:-}"
  [[ -n "$p" && -f "$p" ]]
}

phase2_dir_exists() {
  local p="${1:-}"
  [[ -n "$p" && -d "$p" ]]
}

phase2_open_viewer() {
  # Best-effort view a file: less (preferred) else cat
  local path="${1:-}"
  [[ -n "$path" ]] || return 1
  [[ -f "$path" ]] || { phase2_warn "File not found: $path"; return 1; }

  if command -v less >/dev/null 2>&1; then
    less -R "$path" || true
  else
    cat "$path" || true
  fi
  return 0
}

phase2_safe_source() {
  # Safe wrapper to source a library file.
  local path="${1:-}"
  [[ -n "$path" ]] || return 1

  if [[ -f "$path" ]]; then
    # shellcheck disable=SC1090
    if source "$path"; then
      return 0
    fi
    phase2_warn "Failed sourcing lib (syntax/runtime error): $path (continuing)"
    return 1
  fi

  phase2_warn "Missing lib file: $path (continuing)"
  return 1
}
