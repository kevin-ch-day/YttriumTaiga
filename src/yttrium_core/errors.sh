#!/usr/bin/env bash
# YttriumTaiga core error and diagnostic helpers.

# Source-safe: callers own shell options.

: "${YT_E_OK:=0}"
: "${YT_E_USAGE:=2}"
: "${YT_E_VALIDATION:=10}"
: "${YT_E_IO:=20}"
: "${YT_E_MISSING_TOOL:=30}"
: "${YT_E_INTERNAL:=90}"

yt_ts() {
  date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date
}

yt_info() {
  printf '[INFO] %s\n' "$*"
}

yt_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

yt_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

yt_die() {
  local code="${1:-$YT_E_INTERNAL}"
  shift || true
  yt_error "$*"
  exit "$code"
}

yt_enable_error_trap() {
  local script_name="${1:-script}"
  trap 'rc=$?; line=${LINENO:-unknown}; if [[ "$rc" -ne 0 ]]; then yt_error "Unhandled failure in '"${script_name}"' at line ${line} (exit=${rc})"; fi' ERR
}
