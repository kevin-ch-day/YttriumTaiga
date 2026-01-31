# YttriumTaiga

YttriumTaiga is a phase-based CCDC Red Team operations toolkit: scripts grouped by competition lifecycle phases (setup -> recon -> privilege expansion -> persistence -> end-of-day), with shared libraries that enforce consistent logging, outputs, and operator UX.

## Structure

- `Phase00_Setup/` - Kali bootstrap, updates, and preconfig.
- `Phase01_Recon/` - Read-only recon: inventory, fingerprinting, and operator notes.
- `Phase02_Privilege_Exp/` - Credential ops, remote workflows, safe privesc triage.
- `Phase03_Persistence/` - Placeholder scaffold (phase-local libs in place).
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
- Phase 03 quickstart: `Phase03_Persistence/OPERATOR_QUICKSTART.md`
- Phase 03 smoke test: `Phase03_Persistence/SMOKETEST.md`

## Notes

- Most scripts are designed to be safe and low-noise unless explicitly configured otherwise.
- Phase 0-2 are implemented; Phase 3-5 are scaffolds for future build-out.
- Phase 01 scripts prompt for Team Selection before showing action menus.
- Phase 01 outputs are stored under `Phase01_Recon/output/team_###/` (team-scoped).
