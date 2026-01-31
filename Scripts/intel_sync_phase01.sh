#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: intel_sync_phase01.sh
# Purpose : (Legacy) Copy Phase01 outputs into a shared intel directory
# Run     : ./Scripts/intel_sync_phase01.sh <TEAM_NUMBER>
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PHASE_DIR="${ROOT_DIR}/Phase01_Recon"
INTEL_DIR="${ROOT_DIR}/data/intel"

TEAM="${1:-}"
if [[ -z "$TEAM" ]]; then
  echo "Usage: ./Scripts/intel_sync_phase01.sh <TEAM_NUMBER>" >&2
  exit 1
fi

SRC_DIR="${PHASE_DIR}/output/team_$(printf "%03d" "$TEAM")"
if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: Missing team output dir: $SRC_DIR" >&2
  exit 2
fi

DEST_DIR="${INTEL_DIR}/Phase01_Recon/team_$(printf "%03d" "$TEAM")"
mkdir -p "$DEST_DIR"

copy_if_exists() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp -f "$f" "$DEST_DIR/"
  fi
}

copy_if_exists "${SRC_DIR}/services.csv"
copy_if_exists "${SRC_DIR}/services_hits.txt"
copy_if_exists "${SRC_DIR}/targets_candidates.txt"
copy_if_exists "${SRC_DIR}/web_fingerprint.csv"
copy_if_exists "${SRC_DIR}/web_fingerprint.txt"
copy_if_exists "${SRC_DIR}/cred_ledger.csv"
copy_if_exists "${SRC_DIR}/service_map.csv"
copy_if_exists "${SRC_DIR}/targets_watchlist.csv"

echo "Synced Phase01 intel to: ${DEST_DIR}"
