#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_operator_monitor.sh
# Purpose : Phase 1 Operator - Local Health & Network Snapshot
# Run     : ./phase1_operator_monitor.sh [TEAM_NUMBER]
#
# This is the secondary operator entry point for Phase 01.
# It delegates to phase1_network_monitoring.sh.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${SCRIPT_DIR}/tools/phase1_network_monitoring.sh"

if [[ ! -x "$TARGET" ]]; then
  echo "ERROR: Missing or non-executable: $TARGET" >&2
  exit 2
fi

exec "$TARGET" "$@"
