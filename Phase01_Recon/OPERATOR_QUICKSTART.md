# Phase 01 - Operator Quick Start

## Purpose
Phase 01 is read-only recon. It inventories exposed services, fingerprints web apps,
and sets up operator notes for tracking credentials and targets.

## Recommended run order
1) Initialize operator docs:
   - `./phase1_cred_ledger_init.sh <TEAM>`
2) Run service inventory (HTTP/HTTPS only):
   - `./phase1_service_inventory.sh <TEAM>`
3) Run web fingerprinting (low-noise):
   - `./phase1_web_fingerprint.sh <TEAM>`
4) (Optional) Run network monitoring for local health snapshot:
   - `./phase1_network_monitoring.sh <TEAM>`
5) (Optional) Generate Nmap worksheet (does not scan):
   - `./phase1_nmap_script.sh <TEAM>`

## Outputs and where to find them
All outputs are written under:
- `Phase01_Recon/logs/`
- `Phase01_Recon/output/`

Key files:
- `output/cred_ledger.md` (credential ledger)
- `output/service_map.md` (service tracking)
- `output/targets_watchlist.md` (prioritized targets)
- `output/services.txt` / `output/services.csv` / `output/services_hits.txt`
- `output/targets_candidates.txt`
- `output/web_fingerprint.txt` / `output/web_fingerprint.csv`

## What "good output" looks like
- `services_hits.txt` contains IPs with meaningful headers/titles.
- `web_fingerprint.csv` includes titles/headers for likely apps (webmail, OpenCart, Splunk, etc.).
- `targets_candidates.txt` has a short list of interesting hosts for quick follow-up.

## If the candidate list is empty
`phase1_web_fingerprint.sh` will fall back automatically:
1) `targets_candidates.txt`
2) `services_hits.txt`
3) full public `/24` (slowest)

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
