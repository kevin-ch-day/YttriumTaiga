# Phase 06 - Operator Quick Start (End-of-Day Cleanup)

## Purpose
Phase 06 is for end-of-day cleanup on a temporary Kali VM. It focuses on:
- clearing terminal history
- removing logs and traces
- cleaning package caches

## Recommended run order
Use the menu entry point for guided cleanup:
- `./phase6_operator.sh`

Or run tools directly:

1) Clear **your user** terminal history (do NOT use sudo):
- `./tools/clear_terminal_history.sh`

2) Shred shell history and system logs (requires sudo):
- `sudo CONFIRM=1 ./tools/clear_history.sh`

3) System cleanup (requires sudo):
- `sudo CONFIRM=1 ./tools/system_cleanup.sh`

## Safety notes
- These scripts are destructive. They are intended only at end-of-day.
- `tools/clear_history.sh` shreds system logs; do not run mid-competition.
- `tools/system_cleanup.sh` removes packages and truncates logs; use only after the event.
- If you run `tools/clear_terminal_history.sh` with sudo, it will clear **root** history, not your user history.
- The operator menu option "Shred shell history and system logs" runs
  `tools/clear_history.sh` and requires root privileges.

## Outputs
No formal outputs; scripts print status to the terminal only.
