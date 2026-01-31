#!/usr/bin/env bash
# lib/phase2_lib_net_scheme.sh
set -euo pipefail

# ============================================================
# Purpose : CCDC network scheme + team subnet mapping (Phase 2)
# Version : 0.1.0
#
# Design:
# - Read-only helpers (no scanning).
# - No exits by default; returns non-zero on errors.
# - Uses Phase 2 logging if available (phase2_warn/phase2_log),
#   otherwise prints to stderr/stdout.
#
# Mapping:
# - Default assumes team_octet = TEAM + TEAM_OCTET_BASE (default 20)
#   (example: Team 1 -> 21 when base=20)
# - Optionally load mapping from CSV (PHASE2_TEAM_MAP_CSV),
#   or drop it next to this lib as: lib/ccdc_team_public_ip_map.csv
# ============================================================

# -----------------------------
# Phase 2 defaults (meta can override these)
# -----------------------------
: "${PHASE2_TEAM_OCTET_BASE:=20}"
: "${PHASE2_TEAM_MAP_CSV:=}"

# -----------------------------
# Internal logging shims
# -----------------------------
_phase2_net__warn() {
  local msg="$*"
  if declare -F phase2_warn >/dev/null 2>&1; then
    phase2_warn "$msg"
  elif declare -F ccdc__warn >/dev/null 2>&1; then
    ccdc__warn "$msg"
  else
    echo "WARN: $msg" >&2
  fi
}

_phase2_net__log() {
  local msg="$*"
  if declare -F phase2_log >/dev/null 2>&1; then
    phase2_log "$msg"
  elif declare -F ccdc__log >/dev/null 2>&1; then
    ccdc__log "$msg"
  else
    echo "$msg"
  fi
}

# -----------------------------
# CSV autodiscovery
# -----------------------------
_phase2_net__autodiscover_csv() {
  # If explicitly set, keep it.
  if [[ -n "${PHASE2_TEAM_MAP_CSV}" ]]; then
    return 0
  fi

  # Look for a CSV next to this lib (Phase 2 local)
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || return 0

  # Keep the same conventional CSV name to reduce friction
  local candidate="${lib_dir}/ccdc_team_public_ip_map.csv"
  if [[ -f "$candidate" ]]; then
    PHASE2_TEAM_MAP_CSV="$candidate"
  fi
}

# -----------------------------
# Public setters / printers
# -----------------------------
ccdc_net__set_map_csv() {
  # Usage: ccdc_net__set_map_csv "/path/to/map.csv"
  local csv="${1:-}"
  [[ -n "$csv" && -f "$csv" ]] || return 1
  PHASE2_TEAM_MAP_CSV="$csv"
  return 0
}

ccdc_net__describe_layers() {
  cat <<'EOF'
IP Addressing Structure (CCDC)

1) Internal LAN (172.20.x.x)
   - Hosts servers/workstations
   - Not directly exposed to scoring or Red Team

2) Routing / Firewall Interfaces (172.16.x.x and 172.31.x.x)
   - Router/firewall interconnections ("plumbing")
   - Not service-facing

3) Public IP Pool (172.25.x.0/24)
   - Internet-facing service network
   - Used by scoring engine
   - Primary Red Team interaction surface
EOF
}

ccdc_net__redteam_guidance() {
  cat <<'EOF'
Red Team targeting guidance (Phase 2)

✅ Primary interaction surface:
- 172.25.<team_octet>.0/24  (public/scoring network)

⚠️ Usually "plumbing" (observe only / avoid touching unless rules allow):
- 172.31.<team_octet>.0/29  (core transit)
- 172.16.x.x               (firewall/router interfaces)

❌ Typically not directly accessible from outside / not your initial focus:
- 172.20.x.x               (internal LAN behind firewalls)
EOF
}

# -----------------------------
# Validation
# -----------------------------
ccdc_net__validate_team() {
  local team="${1:-}"
  [[ -n "$team" ]] || return 1
  [[ "$team" =~ ^[0-9]{1,3}$ ]] || return 1
  (( team >= 0 && team <= 255 )) || return 1
  return 0
}

# -----------------------------
# Mapping logic
# -----------------------------
ccdc_net__team_octet_formula() {
  local team="$1"
  echo "$((team + PHASE2_TEAM_OCTET_BASE))"
}

ccdc_net__octet_to_team_formula() {
  local oct="$1"
  echo "$((oct - PHASE2_TEAM_OCTET_BASE))"
}

ccdc_net__team_octet_from_csv() {
  local team="$1"
  _phase2_net__autodiscover_csv

  local csv="${PHASE2_TEAM_MAP_CSV}"
  [[ -n "$csv" && -f "$csv" ]] || return 1
  command -v awk >/dev/null 2>&1 || return 1

  awk -v t="$team" -F',' '
    BEGIN { IGNORECASE=1; team_col=0; oct_col=0; }
    NR==1 {
      for (i=1;i<=NF;i++) {
        h=$i; gsub(/^[ \t"]+|[ \t"]+$/, "", h);
        if (h ~ /^team$/ || h ~ /team[_ ]?number/ ) team_col=i;
        if (h ~ /public[_ ]?octet/ || h ~ /^octet$/ || h ~ /public[_ ]?subnet/ ) oct_col=i;
      }
      next
    }
    {
      if (team_col==0) next;
      v=$team_col; gsub(/^[ \t"]+|[ \t"]+$/, "", v);
      if (v != t) next;

      if (oct_col>0) {
        o=$oct_col; gsub(/^[ \t"]+|[ \t"]+$/, "", o);
        if (o ~ /^[0-9]+\.[0-9]+\.[0-9]+\./) { split(o,a,"."); print a[3]; exit 0 }
        if (o ~ /^[0-9]+$/) { print o; exit 0 }
      }

      for (i=1;i<=NF;i++) {
        s=$i; gsub(/^[ \t"]+|[ \t"]+$/, "", s);
        if (s ~ /^172\.25\.[0-9]+\.0\/24$/) { split(s,a,"."); print a[3]; exit 0 }
      }
    }
    END { exit 1 }
  ' "$csv"
}

ccdc_net__team_octet() {
  local team="${1:-}"
  ccdc_net__validate_team "$team" || return 1

  local o=""
  if o="$(ccdc_net__team_octet_from_csv "$team" 2>/dev/null)"; then
    [[ -n "$o" ]] && { echo "$o"; return 0; }
  fi

  echo "$(ccdc_net__team_octet_formula "$team")"
  return 0
}

# -----------------------------
# Public network helpers
# -----------------------------
ccdc_net__public_subnet() {
  local team="$1"
  local oct
  oct="$(ccdc_net__team_octet "$team")" || return 1
  echo "172.25.${oct}.0/24"
}

ccdc_net__public_host() {
  local team="$1"
  local host="${2:-}"
  [[ "$host" =~ ^[0-9]{1,3}$ ]] || return 1
  (( host >= 0 && host <= 255 )) || return 1

  local oct
  oct="$(ccdc_net__team_octet "$team")" || return 1
  echo "172.25.${oct}.${host}"
}

ccdc_net__public_hosts_range() {
  local team="$1"
  local oct
  oct="$(ccdc_net__team_octet "$team")" || return 1
  local i
  for i in $(seq 1 254); do
    echo "172.25.${oct}.${i}"
  done
}

ccdc_net__public_host_candidates() {
  local team="$1"
  local oct
  oct="$(ccdc_net__team_octet "$team")" || return 1

  local candidates=(1 2 10 20 21 22 25 53 80 110 135 139 143 389 443 445 587 993 995)
  local h
  for h in "${candidates[@]}"; do
    if (( h >= 0 && h <= 255 )); then
      echo "172.25.${oct}.${h}"
    fi
  done
}

# Transit ("plumbing") helpers
ccdc_net__core_transit_router_ip() {
  local team="$1"
  local oct
  oct="$(ccdc_net__team_octet "$team")" || return 1
  echo "172.31.${oct}.1"
}

ccdc_net__core_transit_team_ip() {
  local team="$1"
  local oct
  oct="$(ccdc_net__team_octet "$team")" || return 1
  echo "172.31.${oct}.2"
}

ccdc_net__core_transit_cidr() {
  local team="$1"
  local oct
  oct="$(ccdc_net__team_octet "$team")" || return 1
  echo "172.31.${oct}.0/29"
}

ccdc_net__team_from_public_ip() {
  local ip="${1:-}"
  [[ "$ip" =~ ^172\.25\.([0-9]{1,3})\.[0-9]{1,3}$ ]] || { echo ""; return 1; }
  local oct="${BASH_REMATCH[1]}"
  echo "$(ccdc_net__octet_to_team_formula "$oct")"
}

ccdc_net__print_team_summary() {
  local team="$1"
  if ! ccdc_net__validate_team "$team"; then
    _phase2_net__warn "Invalid team: $team"
    return 1
  fi

  local oct pub transit_cidr core_ip team_ip
  oct="$(ccdc_net__team_octet "$team")" || return 1
  pub="$(ccdc_net__public_subnet "$team")" || return 1
  transit_cidr="$(ccdc_net__core_transit_cidr "$team")" || return 1
  core_ip="$(ccdc_net__core_transit_router_ip "$team")" || return 1
  team_ip="$(ccdc_net__core_transit_team_ip "$team")" || return 1

  _phase2_net__log "Team number:        $team"
  _phase2_net__log "Team octet:         $oct  (base ${PHASE2_TEAM_OCTET_BASE} + team)"
  _phase2_net__log "Public subnet:      $pub"
  _phase2_net__log "Core transit CIDR:  $transit_cidr"
  _phase2_net__log "Core router IP:     $core_ip"
  _phase2_net__log "Team transit IP:    $team_ip"

  if [[ -n "${PHASE2_TEAM_MAP_CSV:-}" ]]; then
    _phase2_net__log "Mapping CSV:        $PHASE2_TEAM_MAP_CSV"
  fi
  return 0
}
