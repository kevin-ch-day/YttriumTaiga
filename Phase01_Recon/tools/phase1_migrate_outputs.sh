#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: phase1_migrate_outputs.sh
# Purpose : Move legacy Phase01 output files into team-scoped folders
# Usage   : ./phase1_migrate_outputs.sh [--force]
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${PHASE_DIR}/output"
TEAM_FILE="${OUT_DIR}/team.txt"
FORCE=0

usage() {
  echo "Usage:"
  echo "  ./$(basename "$0") [--force]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
  shift
done

if [[ "$FORCE" -ne 1 ]]; then
  echo "This will move legacy files under ${OUT_DIR} into team folders."
  read -r -p "Proceed? [y/N]: " ans || ans=""
  ans="${ans,,}"
  if [[ "$ans" != "y" && "$ans" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

if [[ ! -d "$OUT_DIR" ]]; then
  echo "Output directory not found: $OUT_DIR"
  exit 1
fi

stamp="$(date +%Y%m%d_%H%M%S 2>/dev/null || echo legacy)"
legacy_root=""

find "$OUT_DIR" -maxdepth 1 -type f | while read -r f; do
  base="$(basename "$f")"
  if [[ "$base" == "team.txt" ]]; then
    continue
  fi
  # Skip already team-scoped naming
  if [[ "$base" == team_* ]]; then
    continue
  fi

  team=""
  # Try to detect team from IPs in file contents
  oct="$(grep -Eo '172\.25\.[0-9]{1,3}\.[0-9]{1,3}' "$f" 2>/dev/null | head -n 1 | awk -F'.' '{print $3}' || true)"
  if [[ -z "$oct" ]]; then
    oct="$(grep -Eo '172\.31\.[0-9]{1,3}\.[0-9]{1,3}' "$f" 2>/dev/null | head -n 1 | awk -F'.' '{print $3}' || true)"
  fi
  if [[ -n "$oct" && "$oct" =~ ^[0-9]+$ ]]; then
    team=$((oct - 20))
  fi

  # Fallback for docs/templates: use last saved team
  if [[ -z "$team" && -f "$TEAM_FILE" ]]; then
    team="$(cat "$TEAM_FILE" 2>/dev/null || true)"
  fi

  if [[ -z "$team" || ! "$team" =~ ^[0-9]+$ ]]; then
    echo "[*] Skip (cannot map team): $base"
    continue
  fi

  pad="$(printf "%03d" "$team")"
  legacy_root="${OUT_DIR}/team_${pad}/legacy_${stamp}"
  mkdir -p "$legacy_root" 2>/dev/null || true

  dest="${legacy_root}/${base}"
  if [[ -e "$dest" ]]; then
    dest="${legacy_root}/${base}.${stamp}"
  fi
  mv "$f" "$dest"
  echo "[*] Moved ${base} -> ${dest}"
done
