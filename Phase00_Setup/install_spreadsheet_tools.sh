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

step "1) Updating apt metadata"
apt update -y

step "2) Installing LibreOffice Calc"
apt install -y libreoffice-calc

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
