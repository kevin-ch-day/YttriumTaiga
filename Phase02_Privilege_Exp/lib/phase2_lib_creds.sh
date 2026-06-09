#!/usr/bin/env bash
# lib/phase2_lib_creds.sh
set -euo pipefail

# ============================================================
# Phase 2 Credential / Loot Ledger Library
# Version : 0.1.0
#
# Purpose:
# - Track creds/hashes/keys discovered during privilege expansion
# - Write deterministic artifacts under output/loot/
# - Provide safe printing (mask secrets by default)
#
# Integrations:
# - If phase2_lib_runtime.sh is loaded: uses phase2_log/phase2_warn
# - If phase2_lib_utils.sh is loaded: uses phase2__resolve_out_dir
# - Uses Phase 2 meta defaults (OUT_SUBDIR_LOOT, etc.) if sourced
# ============================================================

# -----------------------------
# Internal logging shims
# -----------------------------
_phase2_creds__warn() {
  local msg="$*"
  if declare -F phase2_warn >/dev/null 2>&1; then
    phase2_warn "$msg"
  else
    echo "WARN: $msg" >&2
  fi
}

_phase2_creds__log() {
  local msg="$*"
  if declare -F phase2_log >/dev/null 2>&1; then
    phase2_log "$msg"
  else
    echo "$msg"
  fi
}

# -----------------------------
# Paths
# -----------------------------
phase2_creds__resolve_loot_dir() {
  # Prefer utils helper if available (it already respects runtime/meta)
  local out_dir=""
  if declare -F phase2__resolve_out_dir >/dev/null 2>&1; then
    out_dir="$(phase2__resolve_out_dir)" || return 1
  else
    # fallback: infer phase root from this lib location
    local this_dir
    this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    out_dir="$(cd "$this_dir/.." && pwd)/${PHASE_OUT_DIR:-output}"
  fi

  local loot_sub="${OUT_SUBDIR_LOOT:-loot}"
  echo "${out_dir}/${loot_sub}"
}

phase2_creds__csv_path() {
  local loot_dir
  loot_dir="$(phase2_creds__resolve_loot_dir)" || return 1
  echo "${loot_dir}/cred_ledger.csv"
}

# -----------------------------
# Helpers
# -----------------------------
phase2_creds_mask() {
  # Best-effort secret masking: keep last 4 chars
  local s="${1:-}"
  [[ -n "$s" ]] || { echo ""; return 0; }

  local n=${#s}
  if (( n <= 4 )); then
    echo "****"
    return 0
  fi

  local tail="${s: -4}"
  echo "****${tail}"
}

phase2_creds__csv_escape() {
  # Wrap in quotes, escape inner quotes
  local s="${1:-}"
  s="${s//$'\r'/ }"
  s="${s//$'\n'/ }"
  s="${s//$'\t'/ }"
  s="${s//\"/\"\"}"
  printf "\"%s\"" "$s"
}

phase2_creds__now_utc() {
  # UTC timestamp for ledger rows
  date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S'
}

phase2_creds__new_id() {
  # Lightweight unique-ish ID: epoch + pid + random
  local epoch pid rnd
  epoch="$(date -u '+%s' 2>/dev/null || date '+%s')"
  pid="$$"
  rnd="${RANDOM:-0}"
  echo "c${epoch}-${pid}-${rnd}"
}

# -----------------------------
# Init
# -----------------------------
phase2_creds_init() {
  local loot_dir csv
  loot_dir="$(phase2_creds__resolve_loot_dir)" || return 1
  csv="$(phase2_creds__csv_path)" || return 1

  mkdir -p "$loot_dir" 2>/dev/null || return 1

  if [[ ! -f "$csv" ]]; then
    printf "id,ts_utc,type,username,secret,target,source,status,notes\n" > "$csv" || return 1
    _phase2_creds__log "[*] Created cred ledger CSV: $csv"
  fi

  return 0
}

# -----------------------------
# Add / Update
# -----------------------------
phase2_creds_add() {
  # Usage:
  #   phase2_creds_add "password" "admin" "P@ss" "172.25.21.10:22" "file:/var/www/config.php" "note..."
  #
  # Fields:
  #   type: password|hash|key|token|cookie|api_key|other
  #   status: defaults to "untested"
  local type="${1:-}"
  local username="${2:-}"
  local secret="${3:-}"
  local target="${4:-}"
  local source="${5:-}"
  local notes="${6:-}"
  local status="${7:-untested}"

  [[ -n "$type" ]] || { _phase2_creds__warn "creds_add: missing type"; return 1; }

  phase2_creds_init || return 1

  local id ts csv
  id="$(phase2_creds__new_id)"
  ts="$(phase2_creds__now_utc)"
  csv="$(phase2_creds__csv_path)" || return 1

  # CSV row
  {
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
      "$(phase2_creds__csv_escape "$id")" \
      "$(phase2_creds__csv_escape "$ts")" \
      "$(phase2_creds__csv_escape "$type")" \
      "$(phase2_creds__csv_escape "$username")" \
      "$(phase2_creds__csv_escape "$secret")" \
      "$(phase2_creds__csv_escape "$target")" \
      "$(phase2_creds__csv_escape "$source")" \
      "$(phase2_creds__csv_escape "$status")" \
      "$(phase2_creds__csv_escape "$notes")"
  } >> "$csv" || return 1

  _phase2_creds__log_kv_safe "Cred added" "$id" "$type" "$username" "$target" "$status"

  echo "$id"
  return 0
}

_phase2_creds__log_kv_safe() {
  # internal helper: prints safe info (masked secret not included)
  local label="${1:-Cred}"
  local id="${2:-}"
  local type="${3:-}"
  local user="${4:-}"
  local target="${5:-}"
  local status="${6:-}"
  _phase2_creds__log "[*] ${label}: id=${id} type=${type} user=${user} target=${target} status=${status}"
}

phase2_creds_set_status() {
  # Update status + (optional) notes by ID in CSV.
  # Usage: phase2_creds_set_status "<id>" "valid" "works on ssh"
  local id="${1:-}"
  local new_status="${2:-}"
  local add_notes="${3:-}"

  [[ -n "$id" && -n "$new_status" ]] || return 1
  phase2_creds_init || return 1

  local csv tmp
  csv="$(phase2_creds__csv_path)" || return 1
  tmp="${csv}.tmp.$$"

  command -v awk >/dev/null 2>&1 || { _phase2_creds__warn "awk required for set_status"; return 1; }

  local rc=0
  awk -v id="$id" -v st="$new_status" -v nn="$add_notes" -F',' '
    BEGIN { OFS=","; }
    NR==1 { print; next; }
    {
      # strip quotes for id compare (best effort)
      rid=$1; gsub(/^"+|"+$/, "", rid);
      if (rid==id) {
        matched=1;
        # status col = 8, notes col = 9
        $8="\""st"\"";
        if (nn!="") {
          # append note (preserve existing)
          n=$9; gsub(/^"+|"+$/, "", n);
          if (n=="") n=nn; else n=n" | "nn;
          gsub(/"/, "\"\"", n);
          $9="\""n"\"";
        }
      }
      print;
    }
    END { if (!matched) exit 42; }
  ' "$csv" > "$tmp" || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    rm -f "$tmp"
    if [[ "$rc" -eq 42 ]]; then
      _phase2_creds__warn "No credential ID found: ${id}"
    fi
    return 1
  fi

  mv "$tmp" "$csv" || return 1

  _phase2_creds__log "[*] Updated status for ${id} -> ${new_status}"
  return 0
}

# -----------------------------
# Query
# -----------------------------
phase2_creds_list() {
  # Prints ledger rows (masked secret by default)
  # Usage: phase2_creds_list [--full]
  local mode="${1:-}"
  phase2_creds_init || return 1

  local csv
  csv="$(phase2_creds__csv_path)" || return 1

  if [[ "$mode" == "--full" ]]; then
    cat "$csv"
    return 0
  fi

  command -v awk >/dev/null 2>&1 || { _phase2_creds__warn "awk required for masked credential listing"; return 1; }

  awk -F',' '
    NR==1 { print; next; }
    {
      # mask secret column (5)
      s=$5;
      gsub(/^"+|"+$/, "", s);
      if (length(s)<=4) s="****"; else s="****"substr(s,length(s)-3,4);
      $5="\""s"\"";
      print;
    }
  ' "$csv"
}

phase2_creds_best_for_target() {
  # Best-effort: filter rows whose target contains the provided token.
  # Usage: phase2_creds_best_for_target "172.25.21.10"
  local token="${1:-}"
  [[ -n "$token" ]] || return 1
  phase2_creds_init || return 1

  local csv
  csv="$(phase2_creds__csv_path)" || return 1
  command -v awk >/dev/null 2>&1 || { _phase2_creds__warn "awk required"; return 1; }

  awk -v t="$token" -F',' '
    NR==1 { next; }
    {
      # target col = 6, status col = 8
      tgt=$6; st=$8;
      gsub(/^"+|"+$/, "", tgt);
      gsub(/^"+|"+$/, "", st);
      if (index(tgt, t)>0) {
        s=$5;
        gsub(/^"+|"+$/, "", s);
        if (length(s)<=4) s="****"; else s="****"substr(s,length(s)-3,4);
        $5="\""s"\"";
        print $0;
      }
    }
  ' "$csv"
}
