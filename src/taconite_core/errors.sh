#!/usr/bin/env bash
# Taconite core error and diagnostic helpers.

# Source-safe: callers own shell options.

: "${TACONITE_E_OK:=0}"
: "${TACONITE_E_USAGE:=2}"
: "${TACONITE_E_VALIDATION:=10}"
: "${TACONITE_E_IO:=20}"
: "${TACONITE_E_MISSING_TOOL:=30}"
: "${TACONITE_E_INTERNAL:=90}"

taconite_ts() {
  date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date
}

taconite_info() {
  printf '[INFO] %s\n' "$*"
}

taconite_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

taconite_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

taconite_die() {
  local code="${1:-$TACONITE_E_INTERNAL}"
  shift || true
  taconite_error "$*"
  exit "$code"
}

taconite_enable_error_trap() {
  local script_name="${1:-script}"
  trap 'rc=$?; line=${LINENO:-unknown}; if [[ "$rc" -ne 0 ]]; then taconite_error "Unhandled failure in '"${script_name}"' at line ${line} (exit=${rc})"; fi' ERR
}
