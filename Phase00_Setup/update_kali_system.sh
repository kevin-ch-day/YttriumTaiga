#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: update_kali_system.sh
# Purpose : Phase 0 - Update + full-upgrade Kali safely (single-file)
# Version : 0.3.0
# Updated : 2026-01-30
#
# Run:
#   sudo ./update_kali_system.sh
#
# Output (next to this script):
#   ./logs/update_kali_system.log
#   ./output/update_kali_system.summary.txt
#
# Design:
# - No CLI args (by design)
# - Log filename has NO timestamp (overwrites each run)
# - Low drama: strong preflight, noninteractive, clear summary
# ============================================================

# -------------------------
# Require sudo/root
# -------------------------
if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: Run with sudo:"
  echo "  sudo ./update_kali_system.sh"
  exit 1
fi

# -------------------------
# Paths (next to script)
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
OUT_DIR="${SCRIPT_DIR}/output"
mkdir -p "$LOG_DIR" "$OUT_DIR"

LOG_FILE="${LOG_DIR}/update_kali_system.log"
OUT_FILE="${OUT_DIR}/update_kali_system.summary.txt"

# overwrite each run (no timestamps)
: > "$LOG_FILE"
: > "$OUT_FILE"

# -------------------------
# Tunables (edit here only)
# -------------------------
CONNECT_TIMEOUT_SECS="10"
APT_RETRIES="3"
MIN_FREE_GB="3"             # warn if less than this much free space
NET_TEST_HOST_IP="1.1.1.1"  # may be blocked in CCDC; used as a hint only
DNS_TEST_NAME="example.com"

# -------------------------
# Output helpers
# -------------------------
banner() {
  echo "################################################################################"
  echo "#                    KALI SYSTEM UPDATE (PHASE 0)                              #"
  echo "################################################################################"
}

section() {
  echo "" | tee -a "$LOG_FILE"
  echo "============================================================" | tee -a "$LOG_FILE"
  echo "$*" | tee -a "$LOG_FILE"
  echo "============================================================" | tee -a "$LOG_FILE"
}

log() { echo "$*" | tee -a "$LOG_FILE"; }
append_out() { echo "$*" >> "$OUT_FILE"; }

fail() {
  log "ERROR: $*"
  append_out "RESULT: FAIL - $*"
  exit 2
}

warn() {
  log "WARN: $*"
  append_out "WARN: $*"
}

# -------------------------
# Safety checks
# -------------------------
is_kali() {
  grep -qi "kali" /etc/os-release 2>/dev/null
}

check_apt_locks() {
  local locks=(
    "/var/lib/dpkg/lock"
    "/var/lib/dpkg/lock-frontend"
    "/var/lib/apt/lists/lock"
    "/var/cache/apt/archives/lock"
  )
  for f in "${locks[@]}"; do
    if command -v fuser >/dev/null 2>&1; then
      if fuser "$f" >/dev/null 2>&1; then
        fail "APT/DPKG lock in use: $f (another apt/dpkg process running)"
      fi
    fi
  done
}

check_disk_space() {
  # best-effort free space check on root filesystem
  local avail_kb
  avail_kb="$(df -Pk / | awk 'NR==2 {print $4}' 2>/dev/null || echo "")"
  if [[ -n "$avail_kb" ]]; then
    local avail_gb=$((avail_kb / 1024 / 1024))
    append_out "Disk free on /: ${avail_gb} GB"
    if [[ "$avail_gb" -lt "$MIN_FREE_GB" ]]; then
      warn "Low disk space on / (${avail_gb} GB free). Upgrades may fail."
    fi
  fi
}

net_quick_checks() {
  # These are hints; in CCDC some egress may be blocked. We record results.
  local def_route gw
  def_route="$(ip route show default 2>/dev/null | head -n 1 || true)"
  gw="$(echo "$def_route" | awk '{for(i=1;i<=NF;i++) if($i=="via") print $(i+1)}' | head -n 1 || true)"
  append_out "Default route: ${def_route:-none}"
  append_out "Gateway: ${gw:-unknown}"

  if [[ -n "${gw:-}" ]]; then
    if ping -c 1 -W 1 "$gw" >/dev/null 2>&1; then
      append_out "Ping gateway: ok"
    else
      warn "Ping gateway failed (may still be okay, but network may be unstable)."
    fi
  else
    warn "No default gateway detected (routing may be broken)."
  fi

  if ping -c 1 -W 1 "$NET_TEST_HOST_IP" >/dev/null 2>&1; then
    append_out "Ping ${NET_TEST_HOST_IP}: ok"
  else
    append_out "Ping ${NET_TEST_HOST_IP}: blocked/FAIL (not unusual in CCDC)"
  fi

  # DNS test
  local dns_ok="unknown"
  if command -v dig >/dev/null 2>&1; then
    if dig +time=2 +tries=1 "$DNS_TEST_NAME" A >/dev/null 2>&1; then dns_ok="ok"; else dns_ok="FAIL"; fi
  elif command -v nslookup >/dev/null 2>&1; then
    if nslookup "$DNS_TEST_NAME" >/dev/null 2>&1; then dns_ok="ok"; else dns_ok="FAIL"; fi
  fi
  append_out "DNS resolve ${DNS_TEST_NAME}: ${dns_ok}"
  if [[ "$dns_ok" == "FAIL" ]]; then
    warn "DNS resolution failed. apt-get update may fail unless DNS is fixed."
  fi
}

apt_preflight() {
  # Make apt more resilient in flaky networks.
  mkdir -p /etc/apt/apt.conf.d
  cat >/etc/apt/apt.conf.d/99ccdc-phase0.conf <<EOF
Acquire::Retries "${APT_RETRIES}";
Acquire::http::Timeout "${CONNECT_TIMEOUT_SECS}";
Acquire::https::Timeout "${CONNECT_TIMEOUT_SECS}";
Dpkg::Use-Pty "0";
EOF
  log "[*] Wrote /etc/apt/apt.conf.d/99ccdc-phase0.conf (retries/timeouts)."
}

capture_system_info() {
  {
    echo "START: $(date)"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "Kernel: $(uname -r)"
    echo "OS: $(grep -E '^(PRETTY_NAME|NAME|VERSION)=' /etc/os-release | tr '\n' ' ' || true)"
    echo ""
    echo "APT sources (active deb lines):"
    grep -RhsE '^\s*deb\s+' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true
    echo ""
  } >> "$OUT_FILE"
}

ensure_keyring() {
  # Common Kali failure mode: keyring issues.
  log "[*] Ensuring kali-archive-keyring is present (best-effort)..."
  apt-get -y update >>"$LOG_FILE" 2>&1 || true
  apt-get -y install --reinstall kali-archive-keyring >>"$LOG_FILE" 2>&1 || true
}

count_packages() {
  # package count (best-effort)
  dpkg-query -f '.' -W 2>/dev/null | wc -c | tr -d ' ' || echo "?"
}

do_upgrade() {
  export DEBIAN_FRONTEND=noninteractive

  section "1) apt-get update"
  apt-get update | tee -a "$LOG_FILE"

  section "2) apt-get full-upgrade"
  apt-get -y full-upgrade | tee -a "$LOG_FILE"

  section "3) Cleanup (autoremove + autoclean)"
  apt-get -y autoremove --purge | tee -a "$LOG_FILE"
  apt-get -y autoclean | tee -a "$LOG_FILE"
}

post_checks() {
  section "4) Post-checks"

  local reboot_needed="no"
  if [[ -f /var/run/reboot-required ]]; then
    reboot_needed="yes"
  fi

  local kernel_now pkg_count_now
  kernel_now="$(uname -r)"
  pkg_count_now="$(count_packages)"

  {
    echo "END: $(date)"
    echo ""
    echo "Post-check summary:"
    echo "Kernel now: $kernel_now"
    echo "DPKG package count: $pkg_count_now"
    echo "Reboot required: $reboot_needed"
    echo ""
    echo "Recent apt history (tail):"
    tail -n 60 /var/log/apt/history.log 2>/dev/null || true
    echo ""
  } >> "$OUT_FILE"

  if [[ "$reboot_needed" == "yes" ]]; then
    log "[!] Reboot is recommended (/var/run/reboot-required exists)."
  else
    log "[*] Reboot not strictly required (no reboot-required flag found)."
  fi
}

main() {
  banner | tee -a "$LOG_FILE"
  section "Phase 0: Kali Update + Upgrade"

  if ! is_kali; then
    fail "This does not appear to be Kali (based on /etc/os-release). Refusing to run."
  fi

  section "0) Preflight"
  log "[*] Script dir: $SCRIPT_DIR"
  log "[*] Log file : $LOG_FILE"
  log "[*] Output   : $OUT_FILE"

  log "[*] Checking apt locks..."
  check_apt_locks

  capture_system_info

  # quick environment hints (don’t block unless lock or non-kali)
  section "0a) Quick checks (network/dns/disk)"
  check_disk_space
  if command -v ip >/dev/null 2>&1 && command -v ping >/dev/null 2>&1; then
    net_quick_checks
  else
    warn "Missing ip/ping tools (unexpected). Skipping network checks."
  fi

  section "0b) APT resilience config"
  apt_preflight

  section "0c) Keyring sanity (best-effort)"
  ensure_keyring

  # record pre package count (nice for summary)
  local pkg_count_before
  pkg_count_before="$(count_packages)"
  append_out "DPKG package count (before): $pkg_count_before"

  do_upgrade
  post_checks

  append_out "RESULT: OK"

  section "Done"
  log "[*] Log file : $LOG_FILE"
  log "[*] Summary  : $OUT_FILE"
  echo ""
  echo "[*] Done. See:"
  echo "    $LOG_FILE"
  echo "    $OUT_FILE"
}

main
