# Phase 03 - 5-Minute Smoke Test

1) Scripts executable
   - `chmod +x Phase03_Persistence/phase3_continuity.sh`

2) Logs/output writable
   - `mkdir -p Phase03_Persistence/logs Phase03_Persistence/output`
   - `touch Phase03_Persistence/logs/.smoketest Phase03_Persistence/output/.smoketest`

3) Run continuity script (menu should render)
   - `CAPTAIN_APPROVED=1 ./Phase03_Persistence/phase3_continuity.sh`
   - Exit after menu renders; confirm log file exists in `Phase03_Persistence/logs/`.

4) Confirm outputs exist
   - `Phase03_Persistence/output/footholds.jsonl`
   - `Phase03_Persistence/output/reentry.md`
   - `Phase03_Persistence/output/rules_safety.md`

If any step fails, check the script log in `Phase03_Persistence/logs/` first.
