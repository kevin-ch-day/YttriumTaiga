#!/usr/bin/env bash
# Compatibility adapter for repo-level utility scripts.

# Keep this file source-safe. It should not set shell options for callers.

CCDC_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CCDC_COMMON_ROOT="$(cd "${CCDC_COMMON_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${CCDC_COMMON_ROOT}/src/yttrium_core/kernel.sh"

: "${CCDC_E_OK:=$YT_E_OK}"
: "${CCDC_E_USAGE:=$YT_E_USAGE}"
: "${CCDC_E_VALIDATION:=$YT_E_VALIDATION}"
: "${CCDC_E_IO:=$YT_E_IO}"
: "${CCDC_E_MISSING_TOOL:=$YT_E_MISSING_TOOL}"
: "${CCDC_E_INTERNAL:=$YT_E_INTERNAL}"

ccdc_common__ts() { yt_ts "$@"; }

ccdc_info() {
  yt_info "$@"
}

ccdc_warn() {
  yt_warn "$@"
}

ccdc_error() {
  yt_error "$@"
}

ccdc_die() {
  local code="${1:-$CCDC_E_INTERNAL}"
  shift || true
  yt_die "$code" "$@"
}

ccdc_require_cmds() {
  yt_require_cmds "$@"
}

ccdc_enable_error_trap() {
  yt_enable_error_trap "$@"
}
