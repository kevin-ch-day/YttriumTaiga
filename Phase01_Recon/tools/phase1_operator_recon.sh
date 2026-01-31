#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_operator_recon.sh
# Purpose : Phase 1 Operator - Primary Recon Workflow
# Run     : ./phase1_operator_recon.sh [TEAM_NUMBER]
#
# This is the main operator entry point for Phase 01 recon.
# It delegates to phase1_team_scanning.sh (full recon workflow).
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${SCRIPT_DIR}/phase1_team_scanning.sh"

if [[ ! -x "$TARGET" ]]; then
  echo "ERROR: Missing or non-executable: $TARGET" >&2
  exit 2
fi

exec "$TARGET" "$@"
