# Ops Data (Tracked)

This directory contains the **canonical** ops-tracking data used during the event.

Files:
- `ops_teams.csv` — team metadata + subnet mapping
- `ops_ledger.csv` — action outcomes ledger (one row per action attempt)
- `ops_teams.xlsx` / `ops_ledger.xlsx` — view-only exports

Rules:
- Team19 is reserved for baseline connectivity and must not be targeted.
- Keep CSVs as the source of truth; regenerate XLSX via `Scripts/ops_ledger_export.sh`.
- Log times in Central Time using the format in `config/ccdc_rules.conf` (e.g., `1/21/2026 1:45 PM`).

## Shared intel (cross-phase)
Phase outputs are written into `data/intel/` for cross-phase use:
- Phase01: `data/intel/Phase01_Recon/team_###/`
- Phase02: `data/intel/Phase02_Privilege_Exp/team_###/`
- Phase03: `data/intel/Phase03_Persistence/team_###/`
