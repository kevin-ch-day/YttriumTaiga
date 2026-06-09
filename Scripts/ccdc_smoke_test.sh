#!/usr/bin/env bash
set -euo pipefail

# Non-network smoke tests for core YttriumTaiga phase handoffs.
# Safe on Ubuntu and Kali. Uses temporary directories only.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR=""
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

section() {
  echo ""
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

ok() {
  echo "[ OK ] $*"
  PASS_COUNT=$((PASS_COUNT+1))
}

fail() {
  echo "[FAIL] $*" >&2
  FAIL_COUNT=$((FAIL_COUNT+1))
}

assert_eq() {
  local label="$1"
  local want="$2"
  local got="$3"
  if [[ "$got" == "$want" ]]; then
    ok "$label"
  else
    fail "$label (want='$want' got='$got')"
  fi
}

assert_file() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]]; then ok "$label"; else fail "$label missing: $path"; fi
}

TMP_DIR="$(mktemp -d)"

section "Schema contracts"
if Scripts/ccdc_schema_check.py >/dev/null; then
  ok "schema checker"
else
  fail "schema checker"
fi

section "Network scheme invariants"
if bash -c 'source Phase01_Recon/lib/ccdc_net_scheme.sh; [[ "$(ccdc_net__public_subnet 1)" == "172.25.21.0/24" ]]'; then
  ok "Team 1 public subnet"
else
  fail "Team 1 public subnet"
fi

if bash -c 'source Phase01_Recon/lib/ccdc_net_scheme.sh; ! ccdc_net__validate_team 19 >/dev/null 2>&1'; then
  ok "Team 19 blocked by net scheme"
else
  fail "Team 19 blocked by net scheme"
fi

section "Phase 2 actionable target import"
intel_dir="${TMP_DIR}/intel"
mkdir -p "${intel_dir}/Phase01_Recon/team_001"
cat > "${intel_dir}/Phase01_Recon/team_001/web_fingerprint_hits.csv" <<'EOF'
ip,scheme,port,path,status,title,server,x_powered_by,content_type,set_cookie,location,hints,security_header_gaps,meta_findings
172.25.21.10,http,80,/,200,Jenkins Login,Jetty,,text/html,OCSESSID=x,,jenkins login,missing_csp,robots_meta_paths
EOF

if CCDC_INTEL_DIR="$intel_dir" bash -c 'source Phase02_Privilege_Exp/lib/phase2_lib_intel.sh; phase2_intel__actionable_csv 1 "$CCDC_INTEL_DIR/actionable.csv" >/dev/null'; then
  ok "Phase 2 actionable CSV generated"
else
  fail "Phase 2 actionable CSV generated"
fi

assert_file "Phase 2 actionable CSV exists" "${intel_dir}/actionable.csv"
if rg -q 'phase1_web_hits,HIGH,80,http,jenkins login,web hit meta=robots_meta_paths sec=missing_csp' "${intel_dir}/actionable.csv"; then
  ok "Phase 2 promotes high-signal web finding"
else
  fail "Phase 2 promotes high-signal web finding"
fi

section "Phase 3 continuity import"
mkdir -p "${intel_dir}/Phase01_Recon/team_002"
cat > "${intel_dir}/Phase01_Recon/team_002/services.csv" <<'EOF'
ip,scheme,port,status,server,x_powered_by,content_type,www_authenticate,location,tls_cn,title
172.25.22.10,http,80,200,Apache,,,,,,Portal
EOF

if CCDC_INTEL_DIR="$intel_dir" CAPTAIN_APPROVED=1 CCDC_BATCH=1 bash Phase03_Persistence/tools/phase3_continuity.sh 2 >/dev/null; then
  ok "Phase 3 batch continuity import"
else
  fail "Phase 3 batch continuity import"
fi

p3_dir="${intel_dir}/Phase03_Persistence/team_002"
assert_file "Phase 3 footholds JSONL" "${p3_dir}/footholds.jsonl"
assert_file "Phase 3 footholds CSV" "${p3_dir}/footholds.csv"
if python3 - "$p3_dir/footholds.jsonl" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = [line for line in path.read_text(encoding="utf-8").splitlines() if line]
assert lines
for line in lines:
    json.loads(line)
PY
then
  ok "Phase 3 footholds JSONL is valid"
else
  fail "Phase 3 footholds JSONL is valid"
fi

section "Event-data hygiene"
if Scripts/verify_no_event_data.sh >/dev/null; then
  ok "tracked event-data hygiene"
else
  fail "tracked event-data hygiene"
fi

section "Summary"
echo "Passed : $PASS_COUNT"
echo "Failures: $FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
  exit 1
fi
exit 0
