# Phase 06 - Operator Quick Start (End-of-Day Cleanup)

## Purpose
Phase 06 is for end-of-day cleanup on a temporary Kali VM. It focuses on:
- clearing terminal history
- removing logs and traces
- cleaning package caches

## Recommended run order
1) Clear **your user** terminal history (do NOT use sudo):
   - `./clear_terminal_history.sh`

2) Clear system logs and root history (requires sudo):
   - `sudo CONFIRM=1 ./clear_history.sh`

3) System cleanup (requires sudo):
   - `sudo CONFIRM=1 ./system_cleanup.sh`

## Safety notes
- These scripts are destructive. They are intended only at end-of-day.
- `clear_history.sh` shreds system logs; do not run mid-competition.
- `system_cleanup.sh` removes packages and truncates logs; use only after the event.
- If you run `clear_terminal_history.sh` with sudo, it will clear **root** history, not your user history.

## Outputs
No formal outputs; scripts print status to the terminal only.
