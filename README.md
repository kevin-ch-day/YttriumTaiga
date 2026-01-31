# YttriumTaiga

YttriumTaiga is a phase-based CCDC Red Team operations toolkit: scripts grouped by competition lifecycle phases (setup -> recon -> privilege expansion -> persistence -> end-of-day), with shared libraries that enforce consistent logging, outputs, and operator UX.

## Table of contents

- [Structure](#structure)
- [Phase pattern (shared conventions)](#phase-pattern-shared-conventions)
- [Operator docs](#operator-docs)
- [Ops ledger (root CSVs)](#ops-ledger-root-csvs)
- [Phase quick start (at a glance)](#phase-quick-start-at-a-glance)
- [Outputs and logs](#outputs-and-logs)
- [Network model (Phase 01 default)](#network-model-phase-01-default)
- [Notes](#notes)

## Structure

- `Phase00_Setup/` - Kali bootstrap, updates, and preconfig.
- `Phase01_Recon/` - Read-only recon: inventory, fingerprinting, and operator notes.
- `Phase02_Privilege_Exp/` - Credential ops, remote workflows, safe privesc triage.
- `Phase03_Persistence/` - Persistence-lite continuity (foothold ledger + re-entry planning).
- `Phase04_Controlled_Disruption/` - Placeholder scaffold.
- `Phase05_Kill_Service/` - Placeholder scaffold.
- `Phase06_Day_End/` - Cleanup and end-of-day scripts.
- `Scripts/` - Utility helpers (log monitor, disk usage, service checker, git setup).

## Phase pattern (shared conventions)

- Phase-local `lib/` for shared helpers (runtime/logging, menus, net scheme, HTTP).
- Phase-local `logs/` and `output/` directories created at runtime.
- Deterministic output paths for repeatability under competition stress.

## Operator docs

- Phase 01 quickstart: `Phase01_Recon/OPERATOR_QUICKSTART.md`
- Phase 01 smoke test: `Phase01_Recon/SMOKETEST.md`
- Phase 03 continuity script: `Phase03_Persistence/phase3_continuity.sh`
- Phase 03 quickstart: `Phase03_Persistence/OPERATOR_QUICKSTART.md`
- Phase 03 smoke test: `Phase03_Persistence/SMOKETEST.md`
- Phase 06 quickstart: `Phase06_Day_End/OPERATOR_QUICKSTART.md`
- Phase 06 smoke test: `Phase06_Day_End/SMOKETEST.md`

## Ops ledger (canonical in data/)

- `data/ops_teams.csv` - team metadata and subnet mapping (Team19 is not targetable)
- `data/ops_ledger.csv` - action outcomes matrix (one row per action attempt)
- Excel copies (view only): `data/ops_teams.xlsx`, `data/ops_ledger.xlsx`
- Contract/details: `OPS_LEDGER.md`

## Useful scripts

- Make scripts executable: `Scripts/make_executable.sh`
- Log monitor: `Scripts/log_monitor.sh`
- Disk usage checker: `Scripts/disk_usage_checker.sh`
- Service checker: `Scripts/service_checker.sh`
- Git setup/verify: `Scripts/setup_git.sh`, `Scripts/verify_git.sh`
- Ops ledger add (interactive): `Scripts/ops_ledger_add.sh`
- Ops ledger export (CSV -> XLSX): `Scripts/ops_ledger_export.sh`
- Export helpers (CSV/XLSX/JSONL): `Scripts/export_cli.py`, `Scripts/export_utils.py`

## Phase quick start (at a glance)

1) Phase 0 (Setup)
   - `Phase00_Setup/` scripts prepare Kali. Run once before event.
2) Phase 1 (Recon)
   - `Phase01_Recon/phase1_team_scanning.sh` (menu coordinator)
   - `Phase01_Recon/phase1_service_inventory.sh` (HTTP/HTTPS inventory)
   - `Phase01_Recon/phase1_web_fingerprint.sh` (web hints, low-noise)
3) Phase 2 (Privilege Expansion)
   - `Phase02_Privilege_Exp/phase2_privilege_main.sh` (menu entrypoint)
4) Phase 3 (Continuity)
   - `Phase03_Persistence/phase3_continuity.sh`
5) Phase 6 (End of Day)
   - `Phase06_Day_End/clear_terminal_history.sh`
   - `Phase06_Day_End/clear_history.sh`
   - `Phase06_Day_End/system_cleanup.sh`

## Outputs and logs

Each phase writes artifacts locally under that phase directory:
- `logs/` - runtime logs (per script run)
- `output/` - generated artifacts (CSVs, notes, ledgers)

If you use `sudo`, Phase 01-03 runtimes now fix ownership so you can still edit/delete outputs as your user.

## Network model (Phase 01 default)

- Teams 1-20 only
- Public target subnet: `172.25.(20+team).0/24`
- Transit infra subnet: `172.31.(20+team).0/29` (do not scan)
- Internal LAN behind NAT: `172.20.x.x`

CSV override supported:
- Set `CCDC_TEAM_MAP_CSV=/path/to/ccdc_team_map.csv`, or drop it next to the phase lib.

## Notes

- Most scripts are designed to be safe and low-noise unless explicitly configured otherwise.
- Phase 0-2 are implemented; Phase 3-5 are scaffolds for future build-out.
- Phase 01 scripts prompt for Team Selection before showing action menus.
- Phase 01 outputs are stored under `Phase01_Recon/output/team_###/` (team-scoped).
- Phase 01 operators: `phase1_operator_recon.sh` (primary) and `phase1_operator_monitor.sh` (health).
- Team 19 is reserved as a baseline network and is blocked by validation in all phases.
- Repo rules live in `config/ccdc_rules.conf` (blocked teams, future constraints).
