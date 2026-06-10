# Phase 01 Tools

These are **side scripts** used for single-purpose tasks in Phase 01.
Operators should use the single entry point at the phase root:
- `phase1_operator.sh`

Tools (direct use):
- `phase1_operator_recon.sh` — primary recon workflow (advanced/legacy)
- `phase1_operator_monitor.sh` — local health snapshot
- `phase1_cred_ledger_init.sh` — initialize docs (cred ledger, service map, watchlist)
- `phase1_service_inventory.sh` — HTTP/HTTPS inventory (80/443/8080/8443 by default; tunable)
- `phase1_web_fingerprint.sh` — low-noise fingerprinting
- `phase1_network_monitoring.sh` — local health snapshot
- `phase1_nmap_script.sh` — nmap worksheet generator (no scans)
- `phase1_team_scanning.sh` — full recon workflow coordinator (used by operator)
