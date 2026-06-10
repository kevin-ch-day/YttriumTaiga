#!/usr/bin/env python3
"""Build a read-only cross-phase operator brief for one CCDC team."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]


def warn(message: str) -> None:
    print(f"WARN: {message}", file=sys.stderr)


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    try:
        with path.open(newline="", encoding="utf-8", errors="ignore") as handle:
            return list(csv.DictReader(handle))
    except csv.Error as exc:
        warn(f"failed to parse CSV {path}: {exc}")
    except OSError as exc:
        warn(f"failed to read CSV {path}: {exc}")
    return []


def read_jsonl(path: Path) -> list[dict[str, object]]:
    if not path.is_file():
        return []
    rows: list[dict[str, object]] = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as exc:
                warn(f"skipping malformed JSONL line in {path}: {exc}")
                continue
            if isinstance(obj, dict):
                rows.append(obj)
    return rows


def team_dir(base: Path, phase: str, team: int) -> Path:
    return base / phase / f"team_{team:03d}"


def limit_rows(rows: Iterable[dict[str, str]], limit: int) -> list[dict[str, str]]:
    return list(rows)[:limit]


def md_table(headers: list[str], rows: list[list[str]]) -> list[str]:
    if not rows:
        return ["_No rows._"]
    out = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in rows:
        out.append("| " + " | ".join(cell.replace("\n", " ") for cell in row) + " |")
    return out


def summarize_phase1(p1: Path, limit: int) -> list[str]:
    services = read_csv(p1 / "services.csv")
    web_hits = read_csv(p1 / "web_fingerprint_hits.csv")
    ranked = read_csv(p1 / "targets_ranked.csv")

    lines = ["## Phase 1 - Recon"]
    lines.append(f"- Service rows: {len(services)}")
    lines.append(f"- Web hit rows: {len(web_hits)}")
    lines.append(f"- Ranked targets: {len(ranked)}")

    if ranked:
        rows = [
            [
                row.get("rank", ""),
                row.get("score", ""),
                row.get("ip", ""),
                row.get("reason", ""),
            ]
            for row in limit_rows(ranked, limit)
        ]
        lines.append("")
        lines.append("Top ranked targets:")
        lines.extend(md_table(["Rank", "Score", "IP", "Reason"], rows))

    if web_hits:
        rows = [
            [
                row.get("ip", ""),
                row.get("port", ""),
                row.get("title", ""),
                row.get("hints", ""),
                row.get("meta_findings", ""),
                row.get("security_header_gaps", ""),
            ]
            for row in limit_rows(web_hits, limit)
        ]
        lines.append("")
        lines.append("High-signal web hits:")
        lines.extend(md_table(["IP", "Port", "Title", "Hints", "Meta", "Header gaps"], rows))

    return lines


def summarize_phase2(p2: Path, limit: int) -> list[str]:
    actionable = read_csv(p2 / "phase2_targets_actionable.csv")
    creds = read_csv(p2 / "loot" / "cred_ledger.csv")

    lines = ["## Phase 2 - Privilege Expansion"]
    lines.append(f"- Actionable target rows: {len(actionable)}")
    if actionable:
        priorities = Counter(row.get("priority", "unknown") or "unknown" for row in actionable)
        lines.append("- Priorities: " + ", ".join(f"{k}={v}" for k, v in sorted(priorities.items())))

        rows = [
            [
                row.get("priority", ""),
                row.get("ip", ""),
                row.get("port", ""),
                row.get("service", ""),
                row.get("hints", ""),
                row.get("notes", ""),
            ]
            for row in limit_rows(actionable, limit)
        ]
        lines.append("")
        lines.append("Top actionable targets:")
        lines.extend(md_table(["Priority", "IP", "Port", "Service", "Hints", "Notes"], rows))

    lines.append("")
    lines.append(f"- Credential ledger rows: {len(creds)}")
    if creds:
        by_status = Counter(row.get("status", "unknown") or "unknown" for row in creds)
        by_type = Counter(row.get("type", "unknown") or "unknown" for row in creds)
        lines.append("- Credential status counts: " + ", ".join(f"{k}={v}" for k, v in sorted(by_status.items())))
        lines.append("- Credential type counts: " + ", ".join(f"{k}={v}" for k, v in sorted(by_type.items())))
        lines.append("- Secrets are intentionally not printed in this brief.")

    return lines


def summarize_phase3(p3: Path, limit: int) -> list[str]:
    footholds = read_jsonl(p3 / "footholds.jsonl")
    lines = ["## Phase 3 - Continuity"]
    lines.append(f"- Foothold entries: {len(footholds)}")
    if footholds:
        by_stability = Counter(str(row.get("stability", "unknown") or "unknown") for row in footholds)
        lines.append("- Stability counts: " + ", ".join(f"{k}={v}" for k, v in sorted(by_stability.items())))
        rows = [
            [
                str(row.get("target", "")),
                str(row.get("service", "")),
                str(row.get("identity", "")),
                str(row.get("stability", "")),
                str(row.get("obtained", "")),
            ]
            for row in footholds[:limit]
        ]
        lines.append("")
        lines.append("Foothold summary:")
        lines.extend(md_table(["Target", "Service", "Identity", "Stability", "Obtained"], rows))
    return lines


def build_brief(team: int, intel_dir: Path, limit: int) -> str:
    p1 = team_dir(intel_dir, "Phase01_Recon", team)
    p2 = team_dir(intel_dir, "Phase02_Privilege_Exp", team)
    p3 = team_dir(intel_dir, "Phase03_Persistence", team)

    lines = [
        f"# Team {team:03d} Operator Brief",
        "",
        f"- Intel base: `{intel_dir}`",
        f"- Phase 1 dir: `{p1}`",
        f"- Phase 2 dir: `{p2}`",
        f"- Phase 3 dir: `{p3}`",
        "",
    ]
    lines.extend(summarize_phase1(p1, limit))
    lines.append("")
    lines.extend(summarize_phase2(p2, limit))
    lines.append("")
    lines.extend(summarize_phase3(p3, limit))
    lines.append("")
    lines.append("## Operator notes")
    lines.append("- Use this as a quick brief; verify context before action.")
    lines.append("- This command is read-only and does not run network probes.")
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a read-only cross-phase team brief.")
    parser.add_argument("--team", required=True, type=int, help="Team number (1-20, except 19)")
    parser.add_argument("--intel-dir", type=Path, default=ROOT / "data" / "intel")
    parser.add_argument("--limit", type=int, default=10, help="Max rows per table")
    parser.add_argument("--out", type=Path, default=None, help="Optional output markdown path")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.team < 1 or args.team > 20 or args.team == 19:
        print("ERROR: team must be 1-20 and not Team 19.", file=sys.stderr)
        return 1
    if args.limit < 1:
        print("ERROR: --limit must be positive.", file=sys.stderr)
        return 1

    brief = build_brief(args.team, args.intel_dir.resolve(), args.limit)
    if args.out:
        try:
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(brief, encoding="utf-8")
        except OSError as exc:
            print(f"ERROR: failed to write brief: {exc}", file=sys.stderr)
            return 20
    else:
        print(brief, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
