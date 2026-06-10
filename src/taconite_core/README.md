# Taconite Core

This directory is the shared kernel for Taconite.

The phase folders remain the operator-facing structure. Shared behavior that
should stay consistent across phases belongs here first, then phases can source
it directly or through compatibility adapters.

Modules:

- `kernel.sh` - loads the core modules.
- `errors.sh` - diagnostics, exit codes, and unexpected-failure trap.
- `display.sh` - common headers, sections, key/value output, status lines.
- `paths.sh` - repo root, intel root, and team directory helpers.
- `validate.sh` - command, platform, and team validation helpers.

Guidelines:

- Keep modules source-safe: do not set shell options in module files.
- Do not run commands with side effects at source time.
- Prefer adding cross-cutting behavior here instead of duplicating it in phase
  folders.
- Keep offensive or phase-specific workflow logic in the phase folders.

