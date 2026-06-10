# YttriumTaiga (v1)

YttriumTaiga is a phase-based CCDC Red Team operations toolkit: scripts grouped by competition lifecycle phases (setup -> recon -> privilege expansion -> persistence -> end-of-day), with shared libraries that enforce consistent logging, outputs, and operator UX.

Versioning:
- `config/version.conf` holds the current version and release date.
- `config/version_info.sh` prints the current version banner.

## Table of contents

- [Structure](#structure)
- [Supported platforms](#supported-platforms)
- [Backbone validation](#backbone-validation)
- [Phase pattern (shared conventions)](#phase-pattern-shared-conventions)
- [Operator docs](#operator-docs)
- [Ops ledger (root CSVs)](#ops-ledger-root-csvs)
- [Phase quick start (at a glance)](#phase-quick-start-at-a-glance)
- [Outputs and logs](#outputs-and-logs)
- [Network model (Phase 01 default)](#network-model-phase-01-default)
- [Tuning](#tuning)
- [Notes](#notes)

## Structure

- `Phase00_Setup/` - Kali bootstrap, updates, and preconfig.
- `Phase01_Recon/` - Read-only recon: inventory, fingerprinting, and operator notes.
- `Phase02_Privilege_Exp/` - Credential ops, remote workflows, safe privesc triage.
- `Phase03_Persistence/` - Persistence-lite continuity (foothold ledger + re-entry planning).
- `Phase04_Controlled_Disruption/` - Placeholder scaffold.
- `Phase05_Kill_Service/` - Placeholder scaffold.
- `Phase06_Day_End/` - Cleanup and end-of-day scripts.
- `Scripts/` - Utility helpers (log monitor, disk usage, service checker, git setup, event-data verification).

## Supported platforms

- **Event/operator runtime:** Kali Linux. Phase 00 setup scripts and event-day
  workflows are built around Kali packages, tools, paths, and operator UX.
- **Testing/runtime checks:** Ubuntu is acceptable for lightweight validation such
  as Bash syntax checks, Python parsing, docs checks, and non-network helper
  tests.
- Do not treat Ubuntu as the target production environment for event use unless
  a script explicitly documents Ubuntu support.

## Backbone validation

Core repo contracts are documented in `BACKBONE.md`.

Run the repo-level preflight before event use and before pushing code changes:

```bash
Scripts/ccdc_validate.sh
```

On the Kali event box, use `--strict-kali` to fail when expected event tools are
missing. Use `--with-export` to validate the optional XLSX export dependency,
and `--with-smoke` to run non-network phase handoff tests.

## Phase pattern (shared conventions)

- Phase-local `lib/` for shared helpers (runtime/logging, menus, net scheme, HTTP).
- Phase-local `logs/` and `output/` directories created at runtime.
- Deterministic output paths for repeatability under competition stress.

## Operator docs

- Phase 01 quickstart: `Phase01_Recon/OPERATOR_QUICKSTART.md`
- Phase 02 quickstart: `Phase02_Privilege_Exp/OPERATOR_QUICKSTART.md`
- Phase 01 smoke test: `Phase01_Recon/SMOKETEST.md`
- Phase 03 continuity script: `Phase03_Persistence/tools/phase3_continuity.sh`
- Phase 03 quickstart: `Phase03_Persistence/OPERATOR_QUICKSTART.md`
- Phase 03 smoke test: `Phase03_Persistence/SMOKETEST.md`
- Phase 06 quickstart: `Phase06_Day_End/OPERATOR_QUICKSTART.md`
- Phase 06 smoke test: `Phase06_Day_End/SMOKETEST.md`

## Ops ledger (canonical in data/)

- `data/ops_teams.csv` - team metadata and subnet mapping (Team19 is not targetable)
- `data/ops_ledger.csv` - action outcomes matrix (one row per action attempt)
- Excel copies (view only): generated from CSVs with `Scripts/ops_ledger_export.sh`
- Contract/details: `OPS_LEDGER.md`

## Useful scripts

- Make scripts executable: `Scripts/make_executable.sh`
- Log monitor: `Scripts/log_monitor.sh`
- Disk usage checker: `Scripts/disk_usage_checker.sh`
- Service checker: `Scripts/service_checker.sh`
- Git setup/verify: `Scripts/setup_git.sh`, `Scripts/verify_git.sh`
- Shared utility error helpers: `Scripts/ccdc_common.sh`
- Repo preflight/backbone validation: `Scripts/ccdc_validate.sh`
- Non-network backbone smoke tests: `Scripts/ccdc_smoke_test.sh`
- Cross-phase team brief: `Scripts/ccdc_team_brief.py --team <N>`
- Ops ledger add (interactive): `Scripts/ops_ledger_add.sh`
- Ops ledger export (CSV -> XLSX): `Scripts/ops_ledger_export.sh`
- Export helpers (CSV/XLSX/JSONL): `Scripts/export_cli.py`, `Scripts/export_utils.py`
  - `ops_ledger_add.sh` accepts `Team#` tokens and ranges (e.g., `1-3`) and skips invalid entries.
- Event-data safety check: `Scripts/verify_no_event_data.sh`

## Phase quick start (at a glance)

1) Phase 0 (Setup)
   - `Phase00_Setup/` scripts prepare Kali. Run once before event.
2) Phase 1 (Recon)
   - `Phase01_Recon/phase1_operator.sh` (single entry point)
3) Phase 2 (Privilege Expansion)
   - `Phase02_Privilege_Exp/phase2_operator.sh` (single entry point)
4) Phase 3 (Continuity)
   - `Phase03_Persistence/phase3_operator.sh` (single entry point)
5) Phase 4 (Controlled Disruption)
   - `Phase04_Controlled_Disruption/phase4_operator.sh` (stub)
6) Phase 5 (Kill Service)
   - `Phase05_Kill_Service/phase5_operator.sh` (stub)
7) Phase 6 (End of Day)
   - `Phase06_Day_End/phase6_operator.sh` (single entry point)

## Outputs and logs

Each phase writes runtime logs locally under that phase directory:
- `logs/` - runtime logs (per script run; gitignored)

Phase 01-03 team intel is written centrally for cross-phase use:
- `data/intel/Phase01_Recon/team_###/`
- `data/intel/Phase02_Privilege_Exp/team_###/`
- `data/intel/Phase03_Persistence/team_###/`

Live intel, loot, proof files, credential ledgers, and generated spreadsheets are
gitignored. Run `Scripts/verify_no_event_data.sh` before pushing from event
systems.

If you use `sudo`, Phase 01-03 runtimes now fix ownership so you can still edit/delete outputs as your user.

## Network model (Phase 01 default)

- Teams 1-20 only
- Public target subnet: `172.25.(20+team).0/24`
- Transit infra subnet: `172.31.(20+team).0/29` (do not scan)
- Internal LAN behind NAT: `172.20.x.x`

CSV override supported:
- Set `CCDC_TEAM_MAP_CSV=/path/to/ccdc_team_map.csv`, or drop it next to the phase lib.

## Tuning

Common event-day knobs are documented in `OPERATOR_TUNING.md`.

## Notes

- Most scripts are designed to be safe and low-noise unless explicitly configured otherwise.
- Phase 0-3 are implemented. Phase 3 is persistence-lite continuity
  documentation, not live persistence deployment.
- Phase 4-5 are scaffolds for future build-out.
- Phase 01 scripts prompt for Team Selection before showing action menus.
- Phase 01-03 team intel is stored under `data/intel/<phase>/team_###/`.
  Phase-local `output/` is legacy/fallback runtime state.
- Phase 01 operators: `phase1_operator.sh` (single entry). Advanced tools in `Phase01_Recon/tools/`.
- Team 19 is reserved as a baseline network and is blocked by validation in all phases.
- Repo rules live in `config/ccdc_rules.conf` (blocked teams, future constraints).
- Single entry point per phase:
  - Phase01: `Phase01_Recon/phase1_operator.sh`
  - Phase02: `Phase02_Privilege_Exp/phase2_operator.sh`
  - Phase03: `Phase03_Persistence/phase3_operator.sh`
  - Phase04: `Phase04_Controlled_Disruption/phase4_operator.sh`
  - Phase05: `Phase05_Kill_Service/phase5_operator.sh`
  - Phase06: `Phase06_Day_End/phase6_operator.sh`
