#!/usr/bin/env bash
# lib/ccdc_error.sh
set -euo pipefail

# ============================================================
# Phase 1 Error Helpers (minimal, phase-local)
# Version : 0.1.0
#
# Guardrails:
# - Phase 1 only
# - No behavior changes unless explicitly sourced
# - Wraps existing runtime logging if present
# ============================================================

# ---- Error codes (keep tight) ----
: "${E_OK:=0}"
: "${E_USAGE:=2}"
: "${E_MISSING_TOOL:=10}"
: "${E_IO:=20}"
: "${E_NET:=30}"
: "${E_TIMEOUT:=40}"
: "${E_INTERNAL:=90}"

_ccdc_err__log() {
  local msg="$*"
  if declare -F ccdc__log >/dev/null 2>&1; then
    ccdc__log "$msg"
  else
    echo "$msg"
  fi
}

ccdc_err_warn() {
  # Usage: ccdc_err_warn <code> <msg>
  local code="${1:-${E_INTERNAL}}"
  shift || true
  local msg="$*"

  if declare -F ccdc__warn >/dev/null 2>&1; then
    ccdc__warn "[${code}] ${msg}"
  else
    _ccdc_err__log "WARN [${code}] ${msg}"
  fi
  return 0
}

ccdc_err_die() {
  # Usage: ccdc_err_die <code> <msg>
  local code="${1:-${E_INTERNAL}}"
  shift || true
  local msg="$*"

  _ccdc_err__log "ERROR [${code}] ${msg}"
  exit "$code"
}

ccdc_err_require_cmds() {
  # Usage: ccdc_err_require_cmds <cmd...>
  local missing=0 cmd=""
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      ccdc_err_warn "${E_MISSING_TOOL}" "Missing required command: $cmd"
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    return "${E_MISSING_TOOL}"
  fi
  return 0
}
