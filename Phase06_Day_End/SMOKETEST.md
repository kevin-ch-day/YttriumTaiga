# Phase 06 - 3-Minute Smoke Test

1) Verify scripts are executable
   - `chmod +x Phase06_Day_End/*.sh Phase06_Day_End/tools/*.sh`

2) Dry-run checks (no system impact)
   - Run each script and abort at confirmation prompt:
     - `Phase06_Day_End/tools/clear_terminal_history.sh` (type anything except CLEAR)
     - `sudo Phase06_Day_End/tools/clear_history.sh` (type anything except CLEAR)
     - `sudo Phase06_Day_End/tools/system_cleanup.sh` (type anything except CLEAN)

3) Confirm warnings are shown
   - Root warning appears if `tools/clear_terminal_history.sh` is run with sudo
   - Confirm prompts appear for destructive steps

If any script proceeds without a confirmation prompt, do not use it until fixed.
