#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase5_cleanup.sh
# Purpose : Clean Phase 05 logs and/or output directories
# Usage   : ./phase5_cleanup.sh [--logs|--output|--all] [--force]
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
OUT_DIR="${SCRIPT_DIR}/output"

DO_LOGS=1
DO_OUTPUT=1
FORCE=0

usage() {
  echo "Usage:"
  echo "  ./$(basename "$0") [--logs|--output|--all] [--force]"
  echo ""
  echo "Options:"
  echo "  --logs       Clean logs only"
  echo "  --output     Clean output only"
  echo "  --all        Clean logs and output (default)"
  echo "  --force      Do not prompt for confirmation"
}

clean_dir() {
  local dir="$1"
  local label="$2"
  if [[ ! -d "$dir" ]]; then
    echo "[*] ${label}: not found (${dir})"
    return 0
  fi
  local count
  count="$(find "$dir" -mindepth 1 | wc -l | awk '{print $1}')"
  if [[ "$count" == "0" ]]; then
    echo "[*] ${label}: already clean (${dir})"
    return 0
  fi
  find "$dir" -mindepth 1 -exec rm -rf {} + 2>/dev/null || true
  echo "[*] ${label}: cleaned (${dir})"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --logs) DO_LOGS=1; DO_OUTPUT=0 ;;
    --output) DO_LOGS=0; DO_OUTPUT=1 ;;
    --all) DO_LOGS=1; DO_OUTPUT=1 ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
  shift
done

if [[ "$FORCE" -ne 1 ]]; then
  echo "This will delete contents under:"
  [[ "$DO_LOGS" -eq 1 ]] && echo "  - ${LOG_DIR}"
  [[ "$DO_OUTPUT" -eq 1 ]] && echo "  - ${OUT_DIR}"
  read -r -p "Proceed? [y/N]: " ans || ans=""
  ans="${ans,,}"
  if [[ "$ans" != "y" && "$ans" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

[[ "$DO_LOGS" -eq 1 ]] && clean_dir "$LOG_DIR" "Logs"
[[ "$DO_OUTPUT" -eq 1 ]] && clean_dir "$OUT_DIR" "Output"
