#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Ops Ledger Export (CSV -> XLSX)
# Version : 0.1.0
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${ROOT_DIR}/data"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

PYTHON_BIN=""
if need_cmd python3; then
  PYTHON_BIN="python3"
elif need_cmd python; then
  PYTHON_BIN="python"
else
  echo "ERROR: python3 not found (required for export)." >&2
  exit 2
fi

if [[ ! -f "${SCRIPT_DIR}/export_cli.py" ]]; then
  echo "ERROR: Missing export_cli.py in Scripts/." >&2
  exit 2
fi

if ! "${PYTHON_BIN}" - <<'PY'; then
import sys
try:
    import openpyxl  # noqa: F401
except Exception as exc:
    print("ERROR: Python module 'openpyxl' is required. Install with:", file=sys.stderr)
    print("  pip3 install openpyxl", file=sys.stderr)
    sys.exit(1)
PY
  exit 1
fi

for name in ops_teams ops_ledger; do
  csv_path="${DATA_DIR}/${name}.csv"
  xlsx_path="${DATA_DIR}/${name}.xlsx"
  if [[ ! -f "${csv_path}" ]]; then
    echo "Missing ${csv_path}"
    continue
  fi
  "${PYTHON_BIN}" "${SCRIPT_DIR}/export_cli.py" \
    csv-to-xlsx \
    --csv "${csv_path}" \
    --xlsx "${xlsx_path}" \
    --sheet-name "${name}"
  echo "Wrote ${xlsx_path}"
done
