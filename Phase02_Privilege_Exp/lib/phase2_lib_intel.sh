#!/usr/bin/env bash
# lib/phase2_lib_intel.sh
set -euo pipefail

# ============================================================
# Phase 2 Intel Helpers (Phase 1 -> Phase 2)
# Version : 0.1.0
#
# Purpose:
# - Read Phase 1 intel from central data/intel
# - Summarize useful artifacts
# - Import targets into Phase 2 notes
# ============================================================

_phase2_intel__warn() {
  local msg="$*"
  if declare -F phase2_warn >/dev/null 2>&1; then
    phase2_warn "$msg"
  else
    echo "WARN: $msg" >&2
  fi
}

_phase2_intel__log() {
  local msg="$*"
  if declare -F phase2_log >/dev/null 2>&1; then
    phase2_log "$msg"
  else
    echo "$msg"
  fi
}

phase2_intel__base_dir() {
  local base=""
  if [[ -n "${CCDC_INTEL_DIR:-}" ]]; then
    if [[ "${CCDC_INTEL_DIR}" = /* ]]; then
      base="${CCDC_INTEL_DIR}"
    else
      local phase_dir
      phase_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
      base="${phase_dir}/../${CCDC_INTEL_DIR}"
    fi
  else
    local phase_dir
    phase_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    base="${phase_dir}/../data/intel"
  fi
  echo "$base"
}

phase2_intel__phase1_dir() {
  local team="${1:-}"
  [[ -n "$team" ]] || return 1
  local base
  base="$(phase2_intel__base_dir)"
  printf "%s/Phase01_Recon/team_%03d" "$base" "$team"
}

phase2_intel__summary() {
  local team="${1:-}"
  [[ -n "$team" ]] || return 1

  local p1
  p1="$(phase2_intel__phase1_dir "$team")"
  if [[ ! -d "$p1" ]]; then
    _phase2_intel__warn "Phase 1 intel not found for team ${team}: $p1"
    return 1
  fi

  local services_csv web_csv web_hits ranked_csv
  services_csv="${p1}/services.csv"
  web_hits="${p1}/web_fingerprint_hits.csv"
  web_csv="${p1}/web_fingerprint.csv"
  ranked_csv="${p1}/targets_ranked.csv"

  local c_services c_web c_ranked
  c_services="0"
  c_web="0"
  c_ranked="0"
  [[ -f "$services_csv" ]] && c_services="$(awk -F',' 'NR>1 {c++} END {print c+0}' "$services_csv" 2>/dev/null)"
  if [[ -f "$web_hits" ]]; then
    c_web="$(awk -F',' 'NR>1 {c++} END {print c+0}' "$web_hits" 2>/dev/null)"
  elif [[ -f "$web_csv" ]]; then
    c_web="$(awk -F',' 'NR>1 {c++} END {print c+0}' "$web_csv" 2>/dev/null)"
  fi
  [[ -f "$ranked_csv" ]] && c_ranked="$(awk -F',' 'NR>1 {c++} END {print c+0}' "$ranked_csv" 2>/dev/null)"

  _phase2_intel__log "Phase 1 Intel Summary (team ${team})"
  _phase2_intel__log "  - services.csv rows:          ${c_services}"
  _phase2_intel__log "  - web_fingerprint*.csv rows:  ${c_web}"
  _phase2_intel__log "  - targets_ranked.csv rows:    ${c_ranked}"

  if [[ -f "$ranked_csv" ]]; then
    _phase2_intel__log "  - top ranked targets:"
    awk -F',' 'NR==1 {next} {printf "    * %s (score=%s) %s\n", $3, $2, $4}' "$ranked_csv" 2>/dev/null | head -n 5
  fi
  return 0
}

phase2_intel__summary_plain() {
  local team="${1:-}"
  [[ -n "$team" ]] || return 1

  local p1
  p1="$(phase2_intel__phase1_dir "$team")"
  if [[ ! -d "$p1" ]]; then
    echo "  - No Phase 1 intel found for this team."
    return 1
  fi

  local services_csv web_csv web_hits ranked_csv
  services_csv="${p1}/services.csv"
  web_hits="${p1}/web_fingerprint_hits.csv"
  web_csv="${p1}/web_fingerprint.csv"
  ranked_csv="${p1}/targets_ranked.csv"

  local c_services c_web c_ranked
  c_services="0"
  c_web="0"
  c_ranked="0"
  [[ -f "$services_csv" ]] && c_services="$(awk -F',' 'NR>1 {c++} END {print c+0}' "$services_csv" 2>/dev/null)"
  if [[ -f "$web_hits" ]]; then
    c_web="$(awk -F',' 'NR>1 {c++} END {print c+0}' "$web_hits" 2>/dev/null)"
  elif [[ -f "$web_csv" ]]; then
    c_web="$(awk -F',' 'NR>1 {c++} END {print c+0}' "$web_csv" 2>/dev/null)"
  fi
  [[ -f "$ranked_csv" ]] && c_ranked="$(awk -F',' 'NR>1 {c++} END {print c+0}' "$ranked_csv" 2>/dev/null)"

  echo "  - services.csv rows:          ${c_services}"
  echo "  - web_fingerprint*.csv rows:  ${c_web}"
  echo "  - targets_ranked.csv rows:    ${c_ranked}"
  if [[ -f "$ranked_csv" ]]; then
    echo "  - top ranked targets:"
    awk -F',' 'NR==1 {next} {printf "    * %s (score=%s) %s\n", $3, $2, $4}' "$ranked_csv" 2>/dev/null | head -n 5
  fi
  return 0
}

phase2_intel__import_targets() {
  local team="${1:-}"
  local out_csv="${2:-}"
  [[ -n "$team" && -n "$out_csv" ]] || return 1

  local p1
  p1="$(phase2_intel__phase1_dir "$team")"
  if [[ ! -d "$p1" ]]; then
    _phase2_intel__warn "Phase 1 intel not found for team ${team}: $p1"
    return 1
  fi

  local services_csv web_hits web_csv ranked_csv
  services_csv="${p1}/services.csv"
  web_hits="${p1}/web_fingerprint_hits.csv"
  web_csv="${p1}/web_fingerprint.csv"
  ranked_csv="${p1}/targets_ranked.csv"

  printf "ip,source,score,port,scheme,title,hints,reason\n" > "$out_csv" 2>/dev/null || return 1

  if [[ -f "$ranked_csv" ]]; then
    awk -F',' 'NR==1 {next} {printf "%s,phase1_targets_ranked,%s,,,,,%s\n", $3, $2, $4}' "$ranked_csv" >> "$out_csv" 2>/dev/null || true
  fi

  if [[ -f "$services_csv" ]]; then
    awk -F',' 'NR==1 {next} {printf "%s,phase1_services,,%s,%s,%s,,service %s/%s\n", $1, $3, $2, $11, $2, $3}' "$services_csv" >> "$out_csv" 2>/dev/null || true
  fi

  if [[ -f "$web_hits" ]]; then
    awk -F',' 'NR==1 {next} {printf "%s,phase1_web_hits,,%s,%s,%s,%s,web hit\n", $1, $3, $2, $6, $12}' "$web_hits" >> "$out_csv" 2>/dev/null || true
  elif [[ -f "$web_csv" ]]; then
    awk -F',' 'NR==1 {next} {printf "%s,phase1_web_fingerprint,,%s,%s,%s,%s,web fp\n", $1, $3, $2, $6, $12}' "$web_csv" >> "$out_csv" 2>/dev/null || true
  fi

  _phase2_intel__log "[*] Imported Phase 1 targets -> $out_csv"
  return 0
}

phase2_intel__actionable_csv() {
  # Build a deduped, actionable target list for Phase 2.
  # Output CSV: ip,source,priority,port,service,hints,notes
  local team="${1:-}"
  local out_csv="${2:-}"
  [[ -n "$team" && -n "$out_csv" ]] || return 1

  local p1
  p1="$(phase2_intel__phase1_dir "$team")"
  if [[ ! -d "$p1" ]]; then
    _phase2_intel__warn "Phase 1 intel not found for team ${team}: $p1"
    return 1
  fi

  local services_csv web_hits web_csv ranked_csv
  services_csv="${p1}/services.csv"
  web_hits="${p1}/web_fingerprint_hits.csv"
  web_csv="${p1}/web_fingerprint.csv"
  ranked_csv="${p1}/targets_ranked.csv"

  printf "ip,source,priority,port,service,hints,notes\n" > "$out_csv" 2>/dev/null || return 1

  # 1) Known hosts (highest priority)
  local base known
  base="$(phase2_intel__base_dir)"
  known="${CCDC_KNOWN_HOSTS_CSV:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/data/ops_known_hosts.csv}"
  if [[ -f "$known" ]]; then
    awk -F',' -v team="$team" '
      NR==1 {next}
      {
        t=$1; ip=$2; role=$3; notes=$4;
        gsub(/^[ \t]+|[ \t]+$/, "", t);
        gsub(/^[ \t]+|[ \t]+$/, "", ip);
        if (t==team && ip!="") {
          printf "%s,known_hosts,HIGH,,%s,,%s\n", ip, role, notes;
        }
      }
    ' "$known" >> "$out_csv" 2>/dev/null || true
  fi

  # 2) Ranked targets (high)
  if [[ -f "$ranked_csv" ]]; then
    awk -F',' 'NR==1 {next} {printf "%s,phase1_ranked,HIGH,,,%s,%s\n", $3, $2, $4}' "$ranked_csv" >> "$out_csv" 2>/dev/null || true
  fi

  # 3) Service inventory (medium)
  if [[ -f "$services_csv" ]]; then
    awk -F',' 'NR==1 {next} {printf "%s,phase1_services,MED,%s,%s,%s,%s\n", $1, $3, $2, $11, $5}' "$services_csv" >> "$out_csv" 2>/dev/null || true
  fi

  # 4) Web fingerprint hits (medium)
  if [[ -f "$web_hits" ]]; then
    awk -F',' 'NR==1 {next} {printf "%s,phase1_web_hits,MED,%s,%s,%s,%s\n", $1, $3, $2, $6, $12}' "$web_hits" >> "$out_csv" 2>/dev/null || true
  elif [[ -f "$web_csv" ]]; then
    awk -F',' 'NR==1 {next} {printf "%s,phase1_web_fp,LOW,%s,%s,%s,%s\n", $1, $3, $2, $6, $12}' "$web_csv" >> "$out_csv" 2>/dev/null || true
  fi

  # Dedup by IP+port+source keeping highest priority ordering.
  awk -F',' '
    NR==1 {print; next}
    {
      key=$1"|"$4"|"$2;
      if (!(key in seen)) {seen[key]=1; print}
    }
  ' "$out_csv" > "${out_csv}.tmp" 2>/dev/null && mv "${out_csv}.tmp" "$out_csv"

  _phase2_intel__log "[*] Wrote actionable targets -> $out_csv"
  return 0
}
