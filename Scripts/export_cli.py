#!/usr/bin/env python3
"""
export_cli.py
Small CLI wrapper around export_utils for common conversions.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import tempfile

from export_utils import csv_to_xlsx, jsonl_to_csv, json_to_csv


def cmd_csv_to_xlsx(args: argparse.Namespace) -> int:
    csv_to_xlsx(args.csv, args.xlsx, sheet_name=args.sheet_name)
    return 0


def cmd_jsonl_to_csv(args: argparse.Namespace) -> int:
    headers = args.headers.split(",") if args.headers else None
    jsonl_to_csv(args.jsonl, args.csv, headers=headers)
    return 0


def cmd_json_to_csv(args: argparse.Namespace) -> int:
    headers = args.headers.split(",") if args.headers else None
    json_to_csv(args.json, args.csv, headers=headers, records_key=args.records_key)
    return 0


def cmd_jsonl_to_xlsx(args: argparse.Namespace) -> int:
    headers = args.headers.split(",") if args.headers else None
    with tempfile.NamedTemporaryFile(delete=False, suffix=".csv") as tmp:
        tmp_path = Path(tmp.name)
    try:
        jsonl_to_csv(args.jsonl, tmp_path, headers=headers)
        csv_to_xlsx(tmp_path, args.xlsx, sheet_name=args.sheet_name)
    finally:
        try:
            tmp_path.unlink()
        except FileNotFoundError:
            pass
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Export helpers for CSV/XLSX/JSONL.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_csv_xlsx = sub.add_parser("csv-to-xlsx", help="Convert CSV to XLSX.")
    p_csv_xlsx.add_argument("--csv", required=True, type=Path)
    p_csv_xlsx.add_argument("--xlsx", required=True, type=Path)
    p_csv_xlsx.add_argument("--sheet-name", default=None)
    p_csv_xlsx.set_defaults(func=cmd_csv_to_xlsx)

    p_jsonl_csv = sub.add_parser("jsonl-to-csv", help="Convert JSONL to CSV.")
    p_jsonl_csv.add_argument("--jsonl", required=True, type=Path)
    p_jsonl_csv.add_argument("--csv", required=True, type=Path)
    p_jsonl_csv.add_argument("--headers", default=None, help="Comma-separated header order.")
    p_jsonl_csv.set_defaults(func=cmd_jsonl_to_csv)

    p_json_csv = sub.add_parser("json-to-csv", help="Convert JSON (array) to CSV.")
    p_json_csv.add_argument("--json", required=True, type=Path)
    p_json_csv.add_argument("--csv", required=True, type=Path)
    p_json_csv.add_argument("--headers", default=None, help="Comma-separated header order.")
    p_json_csv.add_argument("--records-key", default=None, help="Optional top-level key containing records.")
    p_json_csv.set_defaults(func=cmd_json_to_csv)

    p_jsonl_xlsx = sub.add_parser("jsonl-to-xlsx", help="Convert JSONL to XLSX.")
    p_jsonl_xlsx.add_argument("--jsonl", required=True, type=Path)
    p_jsonl_xlsx.add_argument("--xlsx", required=True, type=Path)
    p_jsonl_xlsx.add_argument("--sheet-name", default=None)
    p_jsonl_xlsx.add_argument("--headers", default=None, help="Comma-separated header order.")
    p_jsonl_xlsx.set_defaults(func=cmd_jsonl_to_xlsx)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
