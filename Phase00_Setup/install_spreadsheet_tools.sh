#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: install_spreadsheet_tools.sh
# Purpose : Install LibreOffice Calc on Kali (CSV/XLSX editor)
# Version : 1.0.0
# Updated : 2026-01-31
#
# Run:
#   chmod +x install_spreadsheet_tools.sh
#   sudo ./install_spreadsheet_tools.sh
#
# Notes:
# - Installs LibreOffice Calc (GUI spreadsheet tool)
# - Supports CSV and Excel (.xlsx)
# ============================================================

SCRIPT_NAME="$(basename "$0")"
LOG_MODE="${LOG_MODE:-append}"   # append|overwrite

die() {
  echo "ERROR: $*" >&2
  exit 1
}

step() {
  echo
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

if [[ "${EUID}" -ne 0 ]]; then
  die "Run with sudo: sudo ./${SCRIPT_NAME}"
fi

# ---- Shared log helpers (match other install scripts) ----
ensure_shared_dir() {
  local d="$1"
  mkdir -p "$d"
  chmod 1777 "$d" || true
}

ensure_shared_file() {
  local f="$1"
  ensure_shared_dir "$(dirname "$f")"
  touch "$f"
  chmod 0666 "$f" || true
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/install_spreadsheet_tools.log"

ensure_shared_dir "${LOG_DIR}"
ensure_shared_file "${LOG_FILE}"

if [[ "${LOG_MODE}" == "overwrite" ]]; then
  : > "${LOG_FILE}"
fi
ensure_shared_file "${LOG_FILE}"

log() { printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${LOG_FILE}"; }

step "1) Updating apt metadata"
log "Updating apt metadata..."
apt-get update -y 2>&1 | tee -a "${LOG_FILE}"

step "2) Installing LibreOffice Calc"
log "Installing LibreOffice Calc..."
apt-get install -y libreoffice-calc 2>&1 | tee -a "${LOG_FILE}"

step "3) Verifying installation"
if command -v libreoffice >/dev/null 2>&1; then
  echo "[OK] libreoffice found at: $(command -v libreoffice)"
else
  die "libreoffice not found after install"
fi

if command -v soffice >/dev/null 2>&1; then
  echo "[OK] soffice found at: $(command -v soffice)"
fi

echo
echo "LibreOffice version:"
libreoffice --version || true

step "4) Quick usage notes"
cat <<'EOF'
Launch Calc:
  libreoffice --calc

Open a spreadsheet:
  libreoffice --calc ./file.xlsx
  libreoffice --calc ./file.csv

CSV tip:
  Choose the correct delimiter (comma/tab) and UTF-8 encoding when prompted.
EOF

step "DONE"
echo "LibreOffice Calc is installed and ready."
