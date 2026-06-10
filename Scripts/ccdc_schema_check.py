#!/usr/bin/env python3
"""Validate tracked CSV headers against data/schemas/manifest.csv."""

from __future__ import annotations

import csv
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "data" / "schemas" / "manifest.csv"
E_USAGE = 2
E_VALIDATION = 10


@dataclass(frozen=True)
class SchemaEntry:
    name: str
    path: Path
    schema: Path
    required: bool


def read_header(path: Path) -> str:
    with path.open("r", encoding="utf-8", newline="") as handle:
        line = handle.readline()
    return line.rstrip("\r\n")


def load_manifest(path: Path) -> list[SchemaEntry]:
    entries: list[SchemaEntry] = []
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        required_columns = {"name", "path", "schema", "required"}
        if set(reader.fieldnames or []) != required_columns:
            raise ValueError(
                f"manifest header must be: {','.join(sorted(required_columns))}"
            )
        for row in reader:
            entries.append(
                SchemaEntry(
                    name=row["name"],
                    path=ROOT / row["path"],
                    schema=ROOT / row["schema"],
                    required=row["required"].strip().lower() in {"1", "yes", "true"},
                )
            )
    return entries


def validate_entry(entry: SchemaEntry) -> list[str]:
    errors: list[str] = []
    if not entry.schema.is_file():
        errors.append(f"{entry.name}: missing schema file {entry.schema.relative_to(ROOT)}")
        return errors

    if not entry.path.is_file():
        if entry.required:
            errors.append(f"{entry.name}: missing required CSV {entry.path.relative_to(ROOT)}")
        return errors

    expected = read_header(entry.schema)
    actual = read_header(entry.path)
    if actual != expected:
        errors.append(
            f"{entry.name}: header mismatch for {entry.path.relative_to(ROOT)}\n"
            f"  expected: {expected}\n"
            f"  actual:   {actual}"
        )
    return errors


def main(argv: list[str]) -> int:
    manifest = Path(argv[1]).resolve() if len(argv) > 1 else DEFAULT_MANIFEST
    if not manifest.is_file():
        print(f"ERROR: manifest not found: {manifest}", file=sys.stderr)
        return E_USAGE

    try:
        entries = load_manifest(manifest)
    except Exception as exc:  # noqa: BLE001 - CLI should print parse failures clearly.
        print(f"ERROR: failed to read manifest: {exc}", file=sys.stderr)
        return E_USAGE

    errors: list[str] = []
    for entry in entries:
        errors.extend(validate_entry(entry))

    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return E_VALIDATION

    print(f"OK: {len(entries)} CSV schema entries validated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
