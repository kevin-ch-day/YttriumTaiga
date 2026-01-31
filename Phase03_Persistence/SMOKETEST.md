# Phase 03 - 5-Minute Smoke Test

1) Scripts executable
   - `chmod +x Phase03_Persistence/phase3_continuity.sh`

2) Logs/output writable
   - `mkdir -p Phase03_Persistence/logs Phase03_Persistence/output`
   - `touch Phase03_Persistence/logs/.smoketest Phase03_Persistence/output/.smoketest`

3) Run operator (menu should render)
   - `CAPTAIN_APPROVED=1 ./Phase03_Persistence/phase3_operator.sh`
   - If prompted, enter captain initials to create `approved_actions.md`
   - Exit after menu renders; confirm log file exists in `Phase03_Persistence/logs/`.
   - If you only see a prompt, scroll up for the menu.

4) Confirm outputs exist
   - `Phase03_Persistence/output/footholds.jsonl`
   - `Phase03_Persistence/output/reentry.md`
   - `Phase03_Persistence/output/rules_safety.md`
   - `Phase03_Persistence/approved_actions.md` (if prompted)

If any step fails, check the script log in `Phase03_Persistence/logs/` first.
