#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_operator.sh
# Purpose : Phase 1 Operator Launcher (Recon + Monitor)
# Run     : ./phase1_operator.sh [TEAM_NUMBER]
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECON="${SCRIPT_DIR}/phase1_operator_recon.sh"
MONITOR="${SCRIPT_DIR}/phase1_operator_monitor.sh"

if [[ ! -x "$RECON" || ! -x "$MONITOR" ]]; then
  echo "ERROR: Missing operator scripts. Expected:" >&2
  echo "  $RECON" >&2
  echo "  $MONITOR" >&2
  exit 2
fi

echo ""
echo "Phase 01 Operator Launcher"
echo "---------------------------"
echo "1) Recon Operator (primary workflow)"
echo "2) Monitor Operator (local health snapshot)"
echo "0) Exit"

read -r -p "Choose [1-2]: " choice || choice=""

case "$choice" in
  1) exec "$RECON" "$@" ;;
  2) exec "$MONITOR" "$@" ;;
  0|q|Q|"") exit 0 ;;
  *) echo "Invalid selection."; exit 1 ;;
esac
