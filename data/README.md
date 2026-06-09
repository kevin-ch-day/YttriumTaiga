# Ops Data (Tracked)

This directory contains the **canonical** ops-tracking data used during the event.

Files:
- `ops_teams.csv` — team metadata + subnet mapping
- `ops_ledger.csv` — action outcomes ledger (one row per action attempt)
- `ops_known_hosts.csv` — known IPs by team to seed targeting
- `ops_teams.xlsx` / `ops_ledger.xlsx` — generated view-only exports
- `schemas/` — machine-readable CSV header contracts

Rules:
- Team19 is reserved for baseline connectivity and must not be targeted.
- Keep CSVs as the source of truth; regenerate XLSX via `Scripts/ops_ledger_export.sh`
  (or run `Scripts/ops_ledger_add.sh`, which auto-exports by default).
- Log times in Central Time using the format in `config/ccdc_rules.conf` (e.g., `1/21/2026 1:45 PM`).
- Do not commit live event intel, credential ledgers, loot, proof files, or
  session cookies. Run `Scripts/verify_no_event_data.sh` before pushing.
- Validate tracked CSV headers with `Scripts/ccdc_schema_check.py` or the full
  preflight `Scripts/ccdc_validate.sh`.

Ledger helper input:
- `Scripts/ops_ledger_add.sh` accepts comma-separated team numbers, `Team#` tokens,
  and ranges like `1-3`. Invalid entries are skipped with a warning.

## Shared intel (cross-phase)
Phase outputs are written into `data/intel/` for cross-phase use at runtime:
- Phase01: `data/intel/Phase01_Recon/team_###/`
- Phase02: `data/intel/Phase02_Privilege_Exp/team_###/`
- Phase03: `data/intel/Phase03_Persistence/team_###/`

`data/intel/` is gitignored except for its README and `.gitkeep` placeholder.
