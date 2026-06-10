# Taconite Wiring Map

This document explains how the main layers connect.

## Runtime entrypoints

```text
./taconite.sh
  |
  +-- menu                         interactive operating core
  +-- phase <0-6|name>             delegates to phase operators
  +-- validate                     Scripts/ccdc_validate.sh
  +-- smoke                        Scripts/ccdc_smoke_test.sh
  +-- brief --team <N>             Scripts/ccdc_team_brief.py
  +-- version                      config/version_info.sh
```

`./taconite.sh phase ...` hands control to a phase operator with `exec`.
Interactive menu utility actions run as child processes and return to the
`TACONITE>` prompt.

## Core modules

```text
src/taconite_core/kernel.sh
  +-- errors.sh     diagnostics, exit codes, ERR trap
  +-- display.sh    Taconite TUI palette, frames, status lines
  +-- paths.sh      repo root, intel root, team paths
  +-- validate.sh   platform/team/command validation
  +-- app.sh        phase registry and dispatch
```

Repo-level utilities source `Scripts/ccdc_common.sh`, which adapts to
`src/taconite_core/kernel.sh`. New shared utility logic should source the core
directly when possible.

## Phase dispatch

```text
taconite_phase_entry 1  -> Phase01_Recon/phase1_operator.sh
taconite_phase_entry 2  -> Phase02_Privilege_Exp/phase2_operator.sh
taconite_phase_entry 3  -> Phase03_Persistence/phase3_operator.sh
taconite_phase_entry 4  -> Phase04_Controlled_Disruption/phase4_operator.sh
taconite_phase_entry 5  -> Phase05_Kill_Service/phase5_operator.sh
taconite_phase_entry 6  -> Phase06_Day_End/phase6_operator.sh
```

Phase folders remain the operator-facing workflow boundary. The core owns shared
display, validation, errors, and dispatch.

## Intel flow

```text
Phase01_Recon/team_###/
  services.csv
  targets_ranked.csv
  web_fingerprint*.csv
        |
        v
Phase02_Privilege_Exp/team_###/
  phase2_targets_actionable.csv
  proof/
  loot/cred_ledger.csv
        |
        v
Phase03_Persistence/team_###/
  footholds.jsonl
  footholds.csv
  reentry.txt
  rules_safety.txt
```

All runtime intel lives under `data/intel/` by default or the
`CCDC_INTEL_DIR` override.

## Validation wiring

```text
Scripts/ccdc_validate.sh
  +-- requires core files and phase entrypoints
  +-- runs shell/Python syntax checks
  +-- runs Scripts/ccdc_schema_check.py
  +-- runs Scripts/verify_no_event_data.sh
  +-- optionally runs Scripts/ccdc_smoke_test.sh
  +-- optionally runs Scripts/ops_ledger_export.sh
```

Use:

```bash
./taconite.sh validate --with-smoke
```

## Visual wiring

All new shared TUI output should route through `src/taconite_core/display.sh`:

- `taconite_frame`
- `taconite_section`
- `taconite_status`
- `taconite_kv`

The legacy phase theme in `config/theme/` maps old phase menus back into the
same Taconite palette.

