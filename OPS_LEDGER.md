# Red Team Ops Ledger (CSV Contract)

This repo uses two CSV files under the project `data/` directory as the canonical ops ledger:
- `data/ops_teams.csv` (team metadata, stable)
- `data/ops_ledger.csv` (action outcomes, updated during event)

Excel copies are provided for convenience (view only):
- `data/ops_teams.xlsx`
- `data/ops_ledger.xlsx`

## Manual entry helper

An interactive helper is provided to append rows safely:
- `Scripts/ops_ledger_add.sh`

It enforces:
- Team19 cannot be marked Success/Fail
- One row per action attempt

Export helper (CSV -> XLSX):
- `Scripts/ops_ledger_export.sh`
Shared export module:
- `Scripts/export_utils.py` (CSV/XLSX/JSONL helpers)

## data/ops_teams.csv (stable reference)

Purpose: define Team1..Team20 metadata and targeting rules.

Columns:
- `team_id` (Team1..Team20)
- `team_number` (1..20)
- `team_octet` (20 + team)
- `public_subnet_cidr` (172.25.<octet>.0/24)
- `core_transit_cidr` (172.31.<octet>.0/29)
- `core_router_ip` (typically .1)
- `team_router_ip` (typically .2)
- `targetable` (`yes`/`no`)
- `notes` (optional)

Rule: Team19 is `targetable=no` and must never be targeted (use `NA` or blank in the matrix).

## data/ops_ledger.csv (event ledger)

Purpose: one row per action attempt, with outcomes per team.

Non-team columns:
- `date_cst` (YYYY-MM-DD)
- `time_start_cst` (HH:MM)
- `time_end_cst` (HH:MM)
- `action_id` (ACT-001 style)
- `action` (human description)
- `operator` (who ran it)
- `notes` (optional)

Team columns:
- `Team1`..`Team20`

## Outcome states (per team cell)

- `Success` = attempted and succeeded
- `Fail` = attempted and confirmed unsuccessful
- blank = not attempted / unknown
- `NA` = not allowed (Team19 only)

## Rules

- One row = one action attempt.
- Do not write `Fail` unless it was actually attempted.
- Team19 must always be `NA` or blank.
- Keep time fields in CST for consistency.
