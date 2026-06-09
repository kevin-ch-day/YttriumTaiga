# Operator Tuning Reference

Use these knobs to adjust speed, noise, and output locations without editing
scripts. Defaults are conservative for CCDC-style event networks.

## Platform assumption

Run event operations on Kali Linux. Ubuntu is useful for lightweight testing
only, such as syntax checks and non-network validation. Tune package installs,
desktop tooling, and event workflows for Kali first.

## Phase 01 - Recon

Presets are available from `Phase01_Recon/phase1_operator.sh`:

| Preset | Hosts | Max seconds | Fingerprint hosts |
| --- | ---: | ---: | ---: |
| FAST | 64 | 120 | 32 |
| NORMAL | 128 | 300 | 64 |
| FULL | 254 | 0/unlimited | 0/unlimited |

Environment overrides:

- `CCDC_PHASE1_MAX_HOSTS` - cap hosts scanned by inventory.
- `CCDC_PHASE1_MAX_SECONDS` - cap inventory runtime; `0` disables the cap.
- `CCDC_PHASE1_PROGRESS_EVERY` - progress cadence.
- `CCDC_PHASE1_HTTP_PORTS` - inventory ports, default `80,443,8080,8443`.
- `CCDC_PHASE1_FP_MAX_HOSTS` - cap fingerprint targets; `0` disables the cap.
- `CCDC_PHASE1_FP_PORTS` - fingerprint ports, default `80,443,8080,8443`.
- `CCDC_KNOWN_HOSTS_CSV` - override `data/ops_known_hosts.csv`.

HTTP behavior:

- `CCDC_HTTP_TIMEOUT_SECS`
- `CCDC_HTTP_CONNECT_TIMEOUT`
- `CCDC_HTTP_FOLLOW_REDIRECTS=0|1`
- `CCDC_HTTP_UA`

## Phase 02 - Privilege Expansion

CLI presets:

- `./Phase02_Privilege_Exp/phase2_operator.sh --team 1 --preset fast`
- `./Phase02_Privilege_Exp/phase2_operator.sh --all --preset fast`

Environment overrides:

- `PHASE2_HTTP_CONNECT_TIMEOUT`
- `PHASE2_HTTP_TIMEOUT_SECS`
- `PHASE2_SSH_CONNECT_TIMEOUT`
- `PHASE2_REMOTE_MODE=standard|safe|noisy`
- `PHASE2_AUTO_IMPORT=1` - import Phase 1 targets at startup.
- `PHASE2_OUT_DIR` - override the team output directory.

## Phase 03 - Continuity

- `CAPTAIN_APPROVED=1` - allow non-interactive approved writes.
- `CCDC_BATCH=1` - auto-import and generate re-entry skeletons.
- `CCDC_INTEL_DIR` - override central intel base, default `data/intel`.
- `CCDC_OUT_DIR` - override a specific output directory.

## Shared controls

- `CCDC_TEAM_MAP_CSV` - override team-to-subnet mapping.
- `CCDC_BLOCKED_TEAMS` - blocked team list, default `19`.
- `CCDC_QUIET=1` - reduce console output where supported.
- `CCDC_BRIEF=1` - shorter batch logs where supported.

Before pushing event-day changes, run:

```bash
Scripts/verify_no_event_data.sh
```

