# Phase 03 - Operator Quick Start (Persistence-lite)

## Purpose (one sentence)
Phase 03 is recoverable persistence + continuity + documentation. It is reversible and explainable.

## When to run
- Only after you have validated access from Phase 1/2.
- Use it to document footholds, re-entry options, and safety rules.

## What Phase 03 does
- Records footholds and persistence notes in a ledger.
- Generates re-entry + recovery checklists per target.
- Captures safety/authorization rules for the day.

## What Phase 03 will NOT do
- No irreversible persistence.
- No actions that prevent recovery or disable scoring.
- No auth/startup/service tampering beyond reversible, approved changes.

## Outputs (file-based, phase-local)
All outputs live under `Phase03_Persistence/output/`:
- `footholds.jsonl` (session/foothold ledger)
- `reentry.txt` (re-entry + recovery plan)
- `rules_safety.txt` (rules, stop conditions, approvals)

Optional:
- Summary view is available from the menu (counts + top targets).

## Captain approval gate
Actions that write/update these files require approval:
- Provide one of:
  - `CAPTAIN_APPROVED=1`, or
  - `Phase03_Persistence/approved_actions.md` with a quick approval entry.

If approvals file is missing and you have a TTY, the script will prompt for
captain initials and create an entry.

## Recommended run order
1) Operator entry point (recommended):
   - `./phase3_operator.sh`
2) Initialize docs and safety rules:
   - `./tools/phase3_continuity.sh`
2) Add foothold/session entries
3) Generate a re-entry checklist per foothold

## Optional helpers (safe)
- Auto-import footholds from Phase 1/2 outputs
- Generate re-entry sections from existing ledger
- Recovery summary view for defenders

## Stability definition (standardized)
- Stable: repeatable access, survives reboot
- Semi-stable: survives logout, not reboot
- Fragile: session/token based
- Unknown: observed once, not revalidated

## Stop conditions
If you cannot explain the action to the captain in one sentence, stop.

## Menu note
If you only see a prompt without the menu, scroll up; menus print before prompts.
