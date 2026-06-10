#!/usr/bin/env bash
# Compatibility adapter for repo-level utility scripts.

# Keep this file source-safe. It should not set shell options for callers.

CCDC_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CCDC_COMMON_ROOT="$(cd "${CCDC_COMMON_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${CCDC_COMMON_ROOT}/src/taconite_core/kernel.sh"

: "${CCDC_E_OK:=$TACONITE_E_OK}"
: "${CCDC_E_USAGE:=$TACONITE_E_USAGE}"
: "${CCDC_E_VALIDATION:=$TACONITE_E_VALIDATION}"
: "${CCDC_E_IO:=$TACONITE_E_IO}"
: "${CCDC_E_MISSING_TOOL:=$TACONITE_E_MISSING_TOOL}"
: "${CCDC_E_INTERNAL:=$TACONITE_E_INTERNAL}"

ccdc_common__ts() { taconite_ts "$@"; }

ccdc_info() {
  taconite_status info "$@"
}

ccdc_warn() {
  taconite_status warn "$@" >&2
}

ccdc_error() {
  taconite_status fail "$@" >&2
}

ccdc_die() {
  local code="${1:-$CCDC_E_INTERNAL}"
  shift || true
  taconite_die "$code" "$@"
}

ccdc_require_cmds() {
  taconite_require_cmds "$@"
}

ccdc_enable_error_trap() {
  taconite_enable_error_trap "$@"
}
