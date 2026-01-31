#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Ops Ledger Export (CSV -> XLSX)
# Version : 0.1.0
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${ROOT_DIR}/data"

python - <<'PY'
import csv
from pathlib import Path
from openpyxl import Workbook

root = Path('.')
data = root / 'data'
for name in ['ops_teams', 'ops_ledger']:
    csv_path = data / f'{name}.csv'
    xlsx_path = data / f'{name}.xlsx'
    if not csv_path.exists():
        print(f"Missing {csv_path}")
        continue
    wb = Workbook()
    ws = wb.active
    ws.title = name
    with csv_path.open(newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        for row in reader:
            ws.append(row)
    wb.save(xlsx_path)
    print(f"Wrote {xlsx_path}")
PY
