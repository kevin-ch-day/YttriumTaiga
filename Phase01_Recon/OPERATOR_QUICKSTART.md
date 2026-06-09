# Phase 01 - Operator Quick Start

## Purpose
Phase 01 is read-only recon. It inventories exposed services, fingerprints web apps,
and sets up operator notes for tracking credentials and targets.

## Recommended run order
1) **Operator: Single Entry (recommended)**
   - `./phase1_operator.sh`
   - Choose **Team** or **All Teams** (Team19 blocked)
   - The operator will run **all Phase 1 abilities** by default
2) **Operator: Primary Recon (advanced/legacy)**
   - `./tools/phase1_operator_recon.sh <TEAM>`
3) **Operator: Local Health Snapshot (optional)**
   - `./tools/phase1_operator_monitor.sh <TEAM>` (Team is optional; menu allows continue without team)

## Side scripts ("Tools")
If you need a single task without the full operator workflow:
Tools live in `Phase01_Recon/tools/`:
- `./tools/phase1_cred_ledger_init.sh <TEAM>` (docs/ledgers)
- `./tools/phase1_service_inventory.sh <TEAM>` (HTTP/HTTPS inventory)
- `./tools/phase1_web_fingerprint.sh <TEAM>` (light fingerprinting)
- `./tools/phase1_nmap_script.sh <TEAM>` (worksheet only; no scans)

## Phase 01 structure (clean root)
Only `phase1_operator.sh` lives at the phase root. All task-specific scripts are in `tools/`.
This keeps the root minimal and prevents accidental use of the wrong script.

## Menu behavior (what operators should expect)
Every Phase 01 script now starts with a Team Selection menu:
- Use current team (if one was saved previously)
- Enter a new team number
- Exit

After Team Selection, the script’s action menu appears (run, view outputs, exit).

## Outputs and where to find them
All outputs are written under:
- `Phase01_Recon/logs/`
- Central intel: `data/intel/Phase01_Recon/team_###/` (team-scoped)

Key files:
- `data/intel/Phase01_Recon/team_###/cred_ledger.csv` (credential ledger)
- `data/intel/Phase01_Recon/team_###/service_map.csv` (service tracking)
- `data/intel/Phase01_Recon/team_###/targets_watchlist.csv` (prioritized targets)
- `data/intel/Phase01_Recon/team_###/services.txt` / `services.csv` / `services_hits.txt`
- `data/intel/Phase01_Recon/team_###/targets_candidates.txt`
- `data/intel/Phase01_Recon/team_###/web_fingerprint.txt` / `web_fingerprint.csv`

## What "good output" looks like
- `services_hits.txt` contains IPs with meaningful headers/titles.
- `web_fingerprint.csv` includes titles/headers for likely apps (webmail, OpenCart, Splunk, etc.).
- `targets_candidates.txt` has a short list of interesting hosts for quick follow-up.

## Fast test mode (optional)
If you need a quick scan for testing:
- `CCDC_PHASE1_MAX_HOSTS=64`
- `CCDC_PHASE1_MAX_SECONDS=120`
- `CCDC_PHASE1_FP_MAX_HOSTS=32`

## Smart targeting (ranked)
After inventory, a ranked target list is generated:
- `data/intel/Phase01_Recon/team_###/targets_ranked.csv`

## Network model (authoritative)
Teams 1-20 only. The network is fixed for the day:
- Public/DMZ: `172.25.(20+team).0/24` (primary recon surface)
- Transit: `172.31.(20+team).0/29` (router plumbing only)
- Internal LAN: `172.20.x.x` (behind NAT)

Example:
- Team 7 -> Public: `172.25.27.0/24`, Transit: `172.31.27.0/29`

## If the candidate list is empty
`phase1_web_fingerprint.sh` will fall back automatically:
1) `services.csv` from the inventory run
2) `data/ops_known_hosts.csv`
3) `targets_candidates.txt`
4) `services_hits.txt`
5) full public `/24` (slowest)

If results are still empty:
- verify the team/subnet mapping (see `lib/ccdc_net_scheme.sh`)
- verify network connectivity from your Kali host

## Team mapping override
Default mapping is `team + 20` (Teams 1-20 only). Example: Team 1 -> 172.25.21.0/24.
Override this by:
- Setting `CCDC_TEAM_MAP_CSV=/path/to/ccdc_team_map.csv`, or
- Dropping a CSV at `Phase01_Recon/lib/ccdc_team_map.csv`

Expected CSV headers (case-insensitive):
- `team` or `team_number`
- `team_octet` or `public_octet` or `octet`
- `public_subnet_cidr` (preferred) or `public_subnet`
- Optional: `core_transit_cidr`, `core_router_ip`, `team_router_ip`

## Tool prerequisites (typical)
Most Phase 01 scripts expect these tools to exist:
- core: `bash`, `awk`, `sed`, `grep`, `sort`, `head`, `tr`
- network: `curl`, `ip`, `ping`, `ss`
- optional: `dig` or `nslookup` or `host` (DNS check)

## Scope guardrails (admin guidance)
- Target only the team public /24: `172.25.(20+team).0/24`
- Treat transit /29 as infrastructure only: `172.31.(20+team).0/29`
  - `.1` core router side (do not touch)
  - `.2` team router side (do not touch)

## Notes
- These scripts are read-only and low-noise by design.
- All actions log to phase-local logs for traceability.
