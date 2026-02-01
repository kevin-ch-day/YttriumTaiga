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
- Team numbers must be valid (1-20), with invalid entries skipped
- One row per action attempt

Export helper (CSV -> XLSX):
- `Scripts/ops_ledger_export.sh`
Shared export module:
- `Scripts/export_utils.py` (CSV/XLSX/JSONL helpers)
Auto-export behavior:
- `Scripts/ops_ledger_add.sh` runs the export script automatically when
  `OPS_LEDGER_AUTO_EXPORT=1` (default).

Accepted team input formats:
- Comma-separated numbers (e.g., `1,2,7`)
- `Team#` tokens (e.g., `Team4`)
- Ranges (e.g., `1-3`)

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
- `time_start_ct` (e.g., `1/21/2026 1:45 PM`)
- `time_end_ct` (e.g., `1/21/2026 2:10 PM`)
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
- Keep time fields in Central Time for consistency (see `config/ccdc_rules.conf`).
