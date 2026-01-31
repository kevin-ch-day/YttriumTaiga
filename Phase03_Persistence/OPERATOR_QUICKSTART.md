# Phase 03 - Operator Quick Start (Persistence-lite)

## Purpose (one sentence)
Phase 03 is about maintaining access and continuity safely, not deploying persistence or making irreversible changes.

## When to run
- Only after you have validated access from Phase 1/2.
- Use it to document footholds, re-entry options, and safety rules.

## What Phase 03 does
- Records access sessions (footholds) in a ledger.
- Generates re-entry checklists per target.
- Captures safety/authorization rules for the day.

## What Phase 03 will NOT do
- No malware, no stealth implants, no irreversible changes.
- No privilege escalation or service tampering.
- No OS-level persistence unless explicitly approved.

## Outputs (file-based, phase-local)
All outputs live under `Phase03_Persistence/output/`:
- `footholds.jsonl` (session/foothold ledger)
- `reentry.md` (continuity plan/checklists)
- `rules_safety.md` (rules, stop conditions, approvals)

## Captain approval gate
Actions that write/update these files require approval:
- Set `CAPTAIN_APPROVED=1` before running the script, or
- Type `CAPTAIN` when prompted (interactive only).

## Recommended run order
1) Initialize docs and safety rules:
   - `./phase3_continuity.sh`
2) Add foothold/session entries
3) Generate a re-entry checklist per foothold

## Stop conditions
If you cannot explain the action to the captain in one sentence, stop.

## Menu note
If you only see a prompt without the menu, scroll up; menus print before prompts.
