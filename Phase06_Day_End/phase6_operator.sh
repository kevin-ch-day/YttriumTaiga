#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase6_operator.sh
# Purpose : Phase 6 Operator Single Entry Point
# Run     : ./phase6_operator.sh
# ============================================================

PHASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Phase 6 Operator (Day End)"
echo "--------------------------"
echo "1) System cleanup"
echo "2) Clear terminal history"
echo "3) Clear shell history (current session)"
echo "0) Exit"

read -r -p "Choose [1-3]: " choice || choice=""

case "$choice" in
  1) exec "${PHASE_DIR}/system_cleanup.sh" ;;
  2) exec "${PHASE_DIR}/clear_terminal_history.sh" ;;
  3) exec "${PHASE_DIR}/clear_history.sh" ;;
  0|q|Q|"") exit 0 ;;
  *) echo "Invalid selection."; exit 1 ;;
esac
