# Phase 03 - 5-Minute Smoke Test

1) Scripts executable
   - `chmod +x Phase03_Persistence/tools/phase3_continuity.sh`

2) Logs/runtime intel writable
   - `mkdir -p Phase03_Persistence/logs data/intel/Phase03_Persistence/team_001`
   - `touch Phase03_Persistence/logs/.smoketest data/intel/Phase03_Persistence/team_001/.smoketest`

3) Run operator (menu should render)
   - `CAPTAIN_APPROVED=1 ./Phase03_Persistence/phase3_operator.sh`
   - If prompted, enter captain initials to create a live `approved_actions.md`
   - Exit after menu renders; confirm log file exists in `Phase03_Persistence/logs/`.
   - If you only see a prompt, scroll up for the menu.

4) Confirm outputs exist
   - `data/intel/Phase03_Persistence/team_###/footholds.jsonl`
   - `data/intel/Phase03_Persistence/team_###/footholds.csv`
   - `data/intel/Phase03_Persistence/team_###/reentry.txt`
   - `data/intel/Phase03_Persistence/team_###/rules_safety.txt`
   - `Phase03_Persistence/approved_actions.md` with a non-comment `time=... | initials=... | category=...` entry (if prompted)

If any step fails, check the script log in `Phase03_Persistence/logs/` first.
