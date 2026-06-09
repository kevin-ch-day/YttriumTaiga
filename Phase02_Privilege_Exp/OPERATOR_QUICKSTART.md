# Phase 02 - Operator Quick Start

## Purpose
Phase 02 turns access into control: validate creds, collect proof, and perform safe privilege expansion.

## Single entry point (recommended)
- `./phase2_operator.sh`

## Fast batch run (targets only)
- `./phase2_operator.sh --all --preset fast`
  - Runs targets summary for all teams (Team 19 blocked)
  - Uses Phase 1 intel where available

## Team-specific run
- `./phase2_operator.sh --team 1 --preset fast`

## Intel integration
Phase 2 reads Phase 1 intel from:
- `data/intel/Phase01_Recon/team_###/`

In the Phase 2 main menu, use:
- **Intel: Phase 1 summary**
- **Intel: Import Phase 1 targets -> Phase 2 notes**

`phase2_targets_actionable.csv` combines known hosts, ranked Phase 1 targets,
service inventory, and web fingerprint hits. Web hits are prioritized higher
when Phase 1 saw admin/login-style app hints or metadata findings such as
`robots_meta_paths` / cross-domain policy files. Security-header gaps are copied
into the notes column for operator triage.

For a quick cross-phase summary after Phase 1/2/3 artifacts exist:
- `Scripts/ccdc_team_brief.py --team 1`

## Outputs
Phase 2 writes team-scoped intel under:
- `data/intel/Phase02_Privilege_Exp/team_###/`

Common files:
- `phase2_targets_team#.txt`
- `phase2_targets_from_phase1.csv`
- `phase2_targets_actionable.csv`
- `loot/cred_ledger.csv`

## Safety
Phase 2 tools are designed to be read-only by default. Remote actions are explicit and operator-driven.
