# Phase 01 - 5-Minute Smoke Test

Run this once before competition to confirm Phase 01 works end-to-end.

1) Scripts executable
   - `chmod +x Phase01_Recon/*.sh Phase01_Recon/lib/*.sh Phase01_Recon/tools/*.sh`

2) Logs/output writable
   - `mkdir -p Phase01_Recon/logs Phase01_Recon/output`
   - `touch Phase01_Recon/logs/.smoketest Phase01_Recon/output/.smoketest`

3) Team mapping sanity
  - `bash -c 'source Phase01_Recon/lib/ccdc_net_scheme.sh; ccdc_net__public_subnet 1'`
  - Expect: `172.25.21.0/24` unless CSV override is configured.
  - If using CSV: `bash -c 'CCDC_TEAM_MAP_CSV=Phase01_Recon/lib/ccdc_team_map.csv; source Phase01_Recon/lib/ccdc_net_scheme.sh; ccdc_net__public_subnet 7'`
  - Expect: `172.25.27.0/24` for Team 7 with standard mapping.

4) Run operator launcher once
   - `./Phase01_Recon/phase1_operator.sh` (no args)
   - Choose a Team (or All Teams) in the menu.
   - Confirm a log file exists in `Phase01_Recon/logs/`.

5) Confirm outputs exist
   - `data/intel/Phase01_Recon/team_###/cred_ledger.csv`
   - `data/intel/Phase01_Recon/team_###/service_map.csv`
   - `data/intel/Phase01_Recon/team_###/targets_watchlist.csv`
   - Other outputs appear after running inventory/fingerprint scripts.

If any step fails, check the script log in `Phase01_Recon/logs/` first.
