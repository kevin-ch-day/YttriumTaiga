#!/usr/bin/env bash
set -euo pipefail

# Repo-level validation harness for Taconite.
# Safe on Ubuntu for CI/lightweight testing; Kali-specific tool checks warn
# unless --strict-kali is supplied.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "${ROOT_DIR}/Scripts/ccdc_common.sh"
ccdc_enable_error_trap "$(basename "$0")"

STRICT_KALI=0
RUN_EXPORT=0
RUN_SMOKE=0

usage() {
  cat <<'EOF'
Usage: Scripts/ccdc_validate.sh [--strict-kali] [--with-export] [--with-smoke]

Checks:
  - platform context and Kali-vs-Ubuntu expectations
  - required repo files and phase entry points
  - shell/Python syntax
  - executable bits on shell entry points
  - Team 19 / ops ledger invariants
  - tracked event-data hygiene
  - optional non-network smoke tests
  - optional XLSX export path

Options:
  --strict-kali   fail if Kali/event tools are missing
  --with-export   run Scripts/ops_ledger_export.sh
  --with-smoke    run Scripts/ccdc_smoke_test.sh
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --strict-kali) STRICT_KALI=1 ;;
    --with-export) RUN_EXPORT=1 ;;
    --with-smoke) RUN_SMOKE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; ccdc_die "$CCDC_E_USAGE" "Unknown arg: $1" ;;
  esac
  shift || true
done

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

section() {
  taconite_section "$*"
}

ok() {
  taconite_ok "$*"
  PASS_COUNT=$((PASS_COUNT+1))
}

note_warn() {
  echo "[WARN] $*" >&2
  WARN_COUNT=$((WARN_COUNT+1))
}

bad() {
  taconite_fail "$*"
  FAIL_COUNT=$((FAIL_COUNT+1))
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then ok "file exists: $path"; else bad "missing file: $path"; fi
}

check_executable() {
  local path="$1"
  if [[ -x "$path" ]]; then ok "executable: $path"; else bad "not executable: $path"; fi
}

section "Platform"
os_id="$(taconite_platform_id)"
echo "Detected OS: ${os_id}"
case "$os_id" in
  kali) ok "Kali event runtime detected" ;;
  ubuntu) ok "Ubuntu lightweight test runtime detected" ;;
  *) note_warn "Unsupported runtime '${os_id}'. Event runtime is Kali; Ubuntu is test-only." ;;
esac

section "Required files"
required_files=(
  "README.md"
  "OPERATOR_TUNING.md"
  "OPS_LEDGER.md"
  "config/ccdc_rules.conf"
  "data/ops_teams.csv"
  "data/ops_ledger.csv"
  "data/ops_known_hosts.csv"
  "data/schemas/manifest.csv"
  "Scripts/ccdc_common.sh"
  "Scripts/ccdc_schema_check.py"
  "Scripts/ccdc_smoke_test.sh"
  "Scripts/ccdc_team_brief.py"
  "Scripts/verify_no_event_data.sh"
  "src/taconite_core/kernel.sh"
  "src/taconite_core/README.md"
  "src/taconite_core/errors.sh"
  "src/taconite_core/display.sh"
  "src/taconite_core/paths.sh"
  "src/taconite_core/validate.sh"
)
for f in "${required_files[@]}"; do
  check_file "$f"
done

section "Phase entry points"
phase_entrypoints=(
  "Phase01_Recon/phase1_operator.sh"
  "Phase02_Privilege_Exp/phase2_operator.sh"
  "Phase03_Persistence/phase3_operator.sh"
  "Phase04_Controlled_Disruption/phase4_operator.sh"
  "Phase05_Kill_Service/phase5_operator.sh"
  "Phase06_Day_End/phase6_operator.sh"
)
for f in "${phase_entrypoints[@]}"; do
  check_file "$f"
  check_executable "$f"
done

section "Core commands"
core_cmds=(bash awk sed sort uniq head tr wc git)
for cmd in "${core_cmds[@]}"; do
  if need_cmd "$cmd"; then ok "command available: $cmd"; else bad "missing core command: $cmd"; fi
done

kali_cmds=(curl ip ping ssh scp nmap openssl)
for cmd in "${kali_cmds[@]}"; do
  if need_cmd "$cmd"; then
    ok "Kali/event command available: $cmd"
  elif [[ "$STRICT_KALI" == "1" ]]; then
    bad "missing Kali/event command: $cmd"
  else
    note_warn "missing Kali/event command: $cmd"
  fi
done

section "Shell syntax"
if need_cmd git; then
  while IFS= read -r script; do
    [[ -n "$script" ]] || continue
    if bash -n "$script"; then ok "bash -n: $script"; else bad "bash syntax: $script"; fi
  done < <(git ls-files '*.sh')
else
  bad "git required for syntax file list"
fi

section "Python syntax"
if need_cmd python3; then
  if python3 - <<'PY'
from pathlib import Path
import ast
for path in Path(".").rglob("*.py"):
    if ".git" in path.parts:
        continue
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
PY
  then
    ok "Python AST parse"
  else
    bad "Python AST parse"
  fi
else
  note_warn "python3 missing; skipping Python syntax"
fi

section "Repo invariants"
if Scripts/ccdc_schema_check.py; then
  ok "CSV schema manifest"
else
  bad "CSV schema manifest"
fi

if awk -F',' 'NR==20 && $1=="Team19" && $8=="no" {found=1} END{exit found?0:1}' data/ops_teams.csv; then
  ok "Team19 targetable=no in ops_teams.csv"
else
  bad "Team19 targetable=no invariant failed"
fi

if awk -F',' '
  NR==1 {
    for (i=1; i<=NF; i++) seen[$i]=1
    for (t=1; t<=20; t++) {
      key="Team" t
      if (!(key in seen)) exit 1
    }
    exit 0
  }' data/ops_ledger.csv; then
  ok "ops_ledger.csv has Team1-Team20 columns"
else
  bad "ops_ledger.csv header does not match expected team columns"
fi

if [[ -f "Phase03_Persistence/approved_actions.md" ]]; then
  bad "live Phase03_Persistence/approved_actions.md is tracked/present; use approved_actions.md.example"
else
  ok "Phase 3 live approval file absent"
fi

section "Event-data hygiene"
if Scripts/verify_no_event_data.sh; then
  ok "tracked event-data hygiene"
else
  bad "tracked event-data hygiene"
fi

section "Optional export"
if [[ "$RUN_EXPORT" == "1" ]]; then
  if Scripts/ops_ledger_export.sh; then ok "ops ledger export"; else bad "ops ledger export"; fi
else
  note_warn "skipped XLSX export; run with --with-export to test openpyxl path"
fi

section "Optional smoke tests"
if [[ "$RUN_SMOKE" == "1" ]]; then
  if Scripts/ccdc_smoke_test.sh; then ok "non-network smoke tests"; else bad "non-network smoke tests"; fi
else
  note_warn "skipped non-network smoke tests; run with --with-smoke"
fi

section "Summary"
echo "Passed : $PASS_COUNT"
echo "Warnings: $WARN_COUNT"
echo "Failures: $FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
  exit 1
fi
exit 0
