# Red Team Ops Ledger (CSV Contract)

This repo uses two CSV files at the project root as the authoritative ops ledger:
- `teams.csv` (team metadata, stable)
- `ops_matrix.csv` (action outcomes, updated during event)

## teams.csv (stable reference)

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

Rule: Team19 is `targetable=no` and must never be targeted.

## ops_matrix.csv (event ledger)

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
