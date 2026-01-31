#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Ops Ledger Add (interactive helper)
# Writes one row to data/ops_ledger.csv
# Version : 0.1.0
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEAMS_CSV="${ROOT_DIR}/data/ops_teams.csv"
OPS_CSV="${ROOT_DIR}/data/ops_ledger.csv"
OPS_EXPORT="${ROOT_DIR}/Scripts/ops_ledger_export.sh"
RULES_FILE="${ROOT_DIR}/config/ccdc_rules.conf"

die() { echo "ERROR: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

[[ -f "$TEAMS_CSV" ]] || die "Missing ${TEAMS_CSV}"
[[ -f "$OPS_CSV" ]] || die "Missing ${OPS_CSV}"
need_cmd awk || die "awk required"
need_cmd date || die "date required"

# Load repo-wide rules (time format / timezone)
if [[ -f "${RULES_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${RULES_FILE}" || true
fi

CCDC_TIMEZONE="${CCDC_TIMEZONE:-America/Chicago}"
CCDC_TIME_FORMAT="${CCDC_TIME_FORMAT:-%m/%d/%Y %l:%M %p}"

now_stamp="$(TZ="${CCDC_TIMEZONE}" date "+${CCDC_TIME_FORMAT}" 2>/dev/null || date)"

read -r -p "Start time (CT, ${CCDC_TIME_FORMAT}) [${now_stamp}]: " time_start
time_start="${time_start:-$now_stamp}"

read -r -p "End time (CT, ${CCDC_TIME_FORMAT}) [${now_stamp}]: " time_end
time_end="${time_end:-$now_stamp}"

# Compute next ACT-###
next_id="$(awk -F',' 'NR>1 {print $3}' "$OPS_CSV" 2>/dev/null \
  | awk '/^ACT-[0-9]+$/ {gsub("ACT-","",$0); print $0}' \
  | sort -n | tail -n 1)"
if [[ -n "$next_id" ]]; then
  next_id=$(printf "ACT-%03d" $((next_id+1)))
else
  next_id="ACT-001"
fi

read -r -p "Action ID [${next_id}]: " action_id
action_id="${action_id:-$next_id}"

read -r -p "Action (description): " action
[[ -n "$action" ]] || die "Action required"

read -r -p "Operator (initials/name): " operator
[[ -n "$operator" ]] || die "Operator required"

read -r -p "Notes (optional): " notes

# Team outcomes
echo "Enter team numbers for outcomes (comma-separated)."
echo "Example: Success teams: 1,2,7  | Fail teams: 3,9"
read -r -p "Success teams: " success_list
read -r -p "Fail teams: " fail_list

declare -A outcomes
for i in $(seq 1 20); do
  outcomes["Team${i}"]=""
done
outcomes["Team19"]="NA"

normalize_list() {
  echo "$1" | tr -d ' ' | tr ',' ' '
}

for t in $(normalize_list "$success_list"); do
  [[ -n "$t" ]] || continue
  [[ "$t" == "19" ]] && die "Team19 is forbidden; cannot mark Success/Fail."
  outcomes["Team${t}"]="Success"
done

for t in $(normalize_list "$fail_list"); do
  [[ -n "$t" ]] || continue
  [[ "$t" == "19" ]] && die "Team19 is forbidden; cannot mark Success/Fail."
  # prevent overwriting success
  if [[ "${outcomes[Team${t}]}" == "Success" ]]; then
    die "Team${t} cannot be both Success and Fail."
  fi
  outcomes["Team${t}"]="Fail"
done

# Build row (CSV-safe for text fields)
csv_escape() {
  local s="$1"
  s="${s//$'\r'/ }"
  s="${s//$'\n'/ }"
  s="${s//\"/\"\"}"
  printf "\"%s\"" "$s"
}

row="${time_start},${time_end},${action_id},$(csv_escape "$action"),$(csv_escape "$operator"),$(csv_escape "$notes")"
for i in $(seq 1 20); do
  row+=",${outcomes[Team${i}]}"
done

echo "$row" >> "$OPS_CSV"
echo "Wrote row to ${OPS_CSV}"

# Auto-export to XLSX unless disabled
OPS_LEDGER_AUTO_EXPORT="${OPS_LEDGER_AUTO_EXPORT:-1}"
if [[ "$OPS_LEDGER_AUTO_EXPORT" == "1" ]]; then
  if [[ -x "$OPS_EXPORT" ]]; then
    if "$OPS_EXPORT"; then
      echo "Updated XLSX via ${OPS_EXPORT}"
    else
      echo "WARN: XLSX export failed (CSV still updated)." >&2
    fi
  else
    echo "WARN: Missing or non-executable ${OPS_EXPORT} (CSV still updated)." >&2
  fi
fi
