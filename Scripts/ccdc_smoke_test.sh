#!/usr/bin/env bash
set -euo pipefail

# Non-network smoke tests for core YttriumTaiga phase handoffs.
# Safe on Ubuntu and Kali. Uses temporary directories only.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "${ROOT_DIR}/Scripts/ccdc_common.sh"
ccdc_enable_error_trap "$(basename "$0")"

TMP_DIR=""
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

section() {
  yt_section "$*"
}

ok() {
  yt_ok "$*"
  PASS_COUNT=$((PASS_COUNT+1))
}

fail() {
  yt_fail "$*"
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

phase2_out="${intel_dir}/Phase02_Privilege_Exp/team_001"
if CCDC_INTEL_DIR="$intel_dir" PHASE2_BATCH=1 PHASE2_BRIEF=1 bash Phase02_Privilege_Exp/tools/phase2_targets.sh 1 >/dev/null; then
  ok "Phase 2 direct targets run"
else
  fail "Phase 2 direct targets run"
fi
assert_file "Phase 2 direct targets use intel output" "${phase2_out}/phase2_targets_team1.txt"

section "Phase 2 credential CSV handling"
cred_out="${TMP_DIR}/phase2_creds"
mkdir -p "$cred_out"
if PHASE2_OUT_DIR="$cred_out" bash -c '
  source Phase02_Privilege_Exp/lib/phase2_lib_meta.sh
  source Phase02_Privilege_Exp/lib/phase2_lib_creds.sh
  cid="$(phase2_creds_add password admin "alpha,beta" "172.25.21.10:22" "file:/tmp/a,b" "note,with,comma" untested | tail -n1)"
  phase2_creds_best_for_target "172.25.21.10" > "$PHASE2_OUT_DIR/matches.csv"
  ! rg -q "alpha,beta" "$PHASE2_OUT_DIR/matches.csv"
  phase2_creds_set_status "$cid" valid "works,with,comma"
'; then
  ok "Phase 2 credential CSV handles commas and masks filtered output"
else
  fail "Phase 2 credential CSV handles commas and masks filtered output"
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

before_count="$(grep -c '^## Re-entry:' "${p3_dir}/reentry.txt" 2>/dev/null || echo 0)"
if CCDC_INTEL_DIR="$intel_dir" CAPTAIN_APPROVED=1 CCDC_BATCH=1 bash Phase03_Persistence/tools/phase3_continuity.sh 2 >/dev/null; then
  after_count="$(grep -c '^## Re-entry:' "${p3_dir}/reentry.txt" 2>/dev/null || echo 0)"
  assert_eq "Phase 3 re-entry generation is idempotent" "$before_count" "$after_count"
else
  fail "Phase 3 re-entry idempotency rerun"
fi

section "Cross-phase team brief"
mkdir -p "${intel_dir}/Phase02_Privilege_Exp/team_001/loot"
cat > "${intel_dir}/Phase02_Privilege_Exp/team_001/loot/cred_ledger.csv" <<'EOF'
id,ts_utc,type,username,secret,target,source,status,notes
c1,2026-01-01T00:00:00Z,password,admin,supersecret,172.25.21.10:22,manual,valid,works
EOF
if Scripts/ccdc_team_brief.py --team 1 --intel-dir "$intel_dir" --out "${TMP_DIR}/team001.md"; then
  ok "team brief generated"
else
  fail "team brief generated"
fi
assert_file "team brief output exists" "${TMP_DIR}/team001.md"
if rg -q "Jenkins Login" "${TMP_DIR}/team001.md" && ! rg -q "supersecret" "${TMP_DIR}/team001.md"; then
  ok "team brief includes signal and omits secrets"
else
  fail "team brief includes signal and omits secrets"
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
