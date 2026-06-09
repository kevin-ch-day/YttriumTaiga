# YttriumTaiga Backbone

This file documents the core contracts that keep the phase scripts predictable
during a CCDC event.

## Runtime contract

- Event/operator runtime is **Kali Linux**.
- Ubuntu is supported for lightweight validation only: syntax checks, docs
  checks, temporary-file tests, and non-network helper checks.
- Phase entry points live at each phase root:
  - `Phase01_Recon/phase1_operator.sh`
  - `Phase02_Privilege_Exp/phase2_operator.sh`
  - `Phase03_Persistence/phase3_operator.sh`
  - `Phase04_Controlled_Disruption/phase4_operator.sh`
  - `Phase05_Kill_Service/phase5_operator.sh`
  - `Phase06_Day_End/phase6_operator.sh`

## Data contract

- Team 19 is baseline/reserved and must not be targeted.
- `data/ops_teams.csv` and `data/ops_ledger.csv` are tracked source-of-truth
  CSVs.
- CSV headers are governed by `data/schemas/`. `manifest.csv` maps tracked CSVs
  to exact header schemas, and generated runtime artifact schemas are documented
  there as `*.header` files.
- Runtime intel goes under `data/intel/<Phase>/team_###/`.
- Live event intel, credential ledgers, proof files, loot, logs, phase output,
  and generated XLSX files are local runtime artifacts and must not be pushed.

## Validation contract

Run the repo-level preflight before event use and before pushing code changes:

```bash
Scripts/ccdc_validate.sh
```

Useful variants:

```bash
Scripts/ccdc_validate.sh --strict-kali
Scripts/ccdc_validate.sh --with-export
```

The validation harness checks:

- platform context
- required repo files
- phase entry points and executable bits
- core command availability
- Bash and Python syntax
- Team 19 and ops-ledger invariants
- CSV schema drift
- tracked event-data hygiene
- optional XLSX export path

## Phase flow

```text
Phase01_Recon
  services.csv, targets_ranked.csv, web_fingerprint*.csv
        |
        v
Phase02_Privilege_Exp
  phase2_targets_actionable.csv, proof/, loot/cred_ledger.csv
        |
        v
Phase03_Persistence
  footholds.jsonl, footholds.csv, reentry.txt, rules_safety.txt
```

## Change guidelines

- Keep `phaseN_operator.sh` as the supported operator entry point.
- Prefer adding validation to `Scripts/ccdc_validate.sh` when a new invariant is
  introduced.
- Keep low-noise defaults for scans and probes.
- Keep destructive behavior explicit, gated, and documented.
- Do not add live event artifacts to git; add templates or schema docs instead.

