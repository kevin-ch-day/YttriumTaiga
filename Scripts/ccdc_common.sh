#!/usr/bin/env bash
# Common helpers for repo-level utility scripts.

# Keep this file source-safe. It should not set shell options for callers.

: "${CCDC_E_OK:=0}"
: "${CCDC_E_USAGE:=2}"
: "${CCDC_E_VALIDATION:=10}"
: "${CCDC_E_IO:=20}"
: "${CCDC_E_MISSING_TOOL:=30}"
: "${CCDC_E_INTERNAL:=90}"

ccdc_common__ts() {
  date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date
}

ccdc_info() {
  printf '[INFO] %s\n' "$*"
}

ccdc_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

ccdc_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

ccdc_die() {
  local code="${1:-$CCDC_E_INTERNAL}"
  shift || true
  ccdc_error "$*"
  exit "$code"
}

ccdc_require_cmds() {
  local missing=0 cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      ccdc_warn "Missing required command: $cmd"
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || return "$CCDC_E_MISSING_TOOL"
  return "$CCDC_E_OK"
}

ccdc_enable_error_trap() {
  local script_name="${1:-script}"
  # Print the location of unexpected failures while allowing expected failures
  # inside if/while conditionals to be handled by the caller.
  trap 'rc=$?; line=${LINENO:-unknown}; if [[ "$rc" -ne 0 ]]; then ccdc_error "Unhandled failure in '"${script_name}"' at line ${line} (exit=${rc})"; fi' ERR
}
