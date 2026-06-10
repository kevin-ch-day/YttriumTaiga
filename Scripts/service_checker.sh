#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/ccdc_common.sh"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

need_cmd systemctl || ccdc_die "$CCDC_E_MISSING_TOOL" "systemctl is required for service checks"
need_cmd awk || ccdc_die "$CCDC_E_MISSING_TOOL" "awk is required for service checks"

print_table_header() {
  printf "%s\n" "$(taconite_style meta "$(printf '%-40s %-10s' 'SERVICE NAME' 'STATUS')")"
  printf "%s\n" "$(taconite_style meta "$(printf '%-40s %-10s' '########################################' '##########')")"
}

taconite_header "Taconite Service Monitor" "Kali service posture"

taconite_section "Active services"
print_table_header
active_services="$(systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | awk '{printf "%-40s %-10s\n", $1, $4}')"
printf "%s\n" "${active_services:-"(none)"}"

taconite_section "Inactive services"
print_table_header
inactive_services="$(systemctl list-units --type=service --state=inactive --no-pager --no-legend 2>/dev/null | awk '{printf "%-40s %-10s\n", $1, $4}')"
printf "%s\n" "${inactive_services:-"(none)"}"

taconite_section "Service summary"
active_count="$(printf "%s\n" "$active_services" | grep -c ".service" || true)"
inactive_count="$(printf "%s\n" "$inactive_services" | grep -c ".service" || true)"
taconite_kv "Active services" "$active_count"
taconite_kv "Inactive services" "$inactive_count"

taconite_section "Critical service posture"
critical_services=("ssh.service" "nginx.service" "mysql.service")
for service in "${critical_services[@]}"; do
  if systemctl is-enabled "$service" >/dev/null 2>&1 && ! systemctl is-active "$service" >/dev/null 2>&1; then
    printf "%s %s\n" "$(taconite_style accent "[CRITICAL]")" "$(taconite_style data "$service inactive")"
  else
    printf "%s %s\n" "$(taconite_style meta "[ OK ]")" "$(taconite_style data "$service active or not enabled")"
  fi
done

taconite_section "Service check complete"