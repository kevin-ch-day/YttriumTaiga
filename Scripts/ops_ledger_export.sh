#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Ops Ledger Export (CSV -> XLSX)
# Version : 0.1.0
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${ROOT_DIR}/data"

for name in ops_teams ops_ledger; do
  csv_path="${DATA_DIR}/${name}.csv"
  xlsx_path="${DATA_DIR}/${name}.xlsx"
  if [[ ! -f "${csv_path}" ]]; then
    echo "Missing ${csv_path}"
    continue
  fi
  python "${SCRIPT_DIR}/export_cli.py" \
    csv-to-xlsx \
    --csv "${csv_path}" \
    --xlsx "${xlsx_path}" \
    --sheet-name "${name}"
  echo "Wrote ${xlsx_path}"
done
