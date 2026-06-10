#!/usr/bin/env bash
# filename: log_monitor.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/ccdc_common.sh"

# ============================================================
# Real-Time Log Monitor (Event-Day Safe)
# Version : 0.3.0
#
# Goals:
# - Monitor common security-relevant logs on Kali/Debian-based systems
# - Gracefully handle missing logs (common on minimal images / journald)
# - Optional keyword highlighting (alerts + info)
# - Never crash the whole script if one log disappears
#
# Usage:
#   sudo ./log_monitor.sh
#   ./log_monitor.sh --user      # best-effort without sudo (may miss auth logs)
#
# Options:
#   --user           # do not require root (best-effort)
#   --all            # include more log candidates
#   --no-color       # disable ANSI colors
#   --pattern "..."  # override alert regex (case-insensitive)
# ============================================================

REQUIRE_ROOT=1
INCLUDE_ALL=0
USE_COLOR=1
ALERT_RE='failed|error|critical|denied|unauthorized|invalid|forbidden|refused|authentication failure|segfault|panic'
INFO_RE='success|accepted|logged in|session opened|connected'

while (( $# > 0 )); do
  case "$1" in
    --user) REQUIRE_ROOT=0 ;;
    --all) INCLUDE_ALL=1 ;;
    --no-color) USE_COLOR=0 ;;
    --pattern) shift; ALERT_RE="${1:-$ALERT_RE}" ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--user] [--all] [--no-color] [--pattern "regex"]
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift || true
done

if [[ "$REQUIRE_ROOT" == "1" && "${EUID}" -ne 0 ]]; then
  echo "ERROR: Run with sudo for best coverage:"
  echo "  sudo ./log_monitor.sh"
  echo "Or run best-effort mode:"
  echo "  ./log_monitor.sh --user"
  exit 1
fi

c() {
  local code="$1"; shift
  local text="$*"
  if [[ "$USE_COLOR" == "1" ]]; then
    taconite_color "$code" "$text"
  else
    printf "%s" "$text"
  fi
}

section() {
  taconite_section "$*"
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# -----------------------------
# Discover log files
# -----------------------------
LOG_FILES=()

add_if_exists() {
  local p="$1"
  if [[ -f "$p" ]]; then
    LOG_FILES+=("$p")
  fi
}

# Debian/Kali common
add_if_exists "/var/log/syslog"
add_if_exists "/var/log/auth.log"
add_if_exists "/var/log/kern.log"
add_if_exists "/var/log/daemon.log"

# Some Kali images use these
add_if_exists "/var/log/messages"
add_if_exists "/var/log/user.log"

# Add more if requested
if [[ "$INCLUDE_ALL" == "1" ]]; then
  add_if_exists "/var/log/apache2/access.log"
  add_if_exists "/var/log/apache2/error.log"
  add_if_exists "/var/log/nginx/access.log"
  add_if_exists "/var/log/nginx/error.log"
  add_if_exists "/var/log/mysql/error.log"
  add_if_exists "/var/log/mariadb/mariadb.log"
  add_if_exists "/var/log/postgresql/postgresql-*.log"
  add_if_exists "/var/log/samba/log.smbd"
  add_if_exists "/var/log/samba/log.nmbd"
fi

# De-duplicate
if need_cmd awk; then
  mapfile -t LOG_FILES < <(printf "%s\n" "${LOG_FILES[@]}" | awk '!seen[$0]++')
fi

# If none, suggest journald
if (( ${#LOG_FILES[@]} == 0 )); then
  section "No file-based logs found"
  echo "$(c "1;93" "[WARN]") No valid log files found under /var/log."
  echo ""
  echo "If this system uses journald, try:"
  echo "  sudo journalctl -f"
  echo ""
  echo "Or run with --all to try extra service logs."
  exit 1
fi

# -----------------------------
# Show monitored logs
# -----------------------------
section "Monitoring These Log Files"
for f in "${LOG_FILES[@]}"; do
  echo "$(c "1;92" "[OK]") $f"
done

echo ""
echo "$(c "1;96" "Press Ctrl+C to stop.")"
echo ""

# -----------------------------
# Tail + highlight
# -----------------------------
if ! need_cmd tail; then
  echo "ERROR: tail not found." >&2
  exit 1
fi

# Use awk highlighting if available; otherwise plain tail.
if need_cmd awk; then
  # -F follows renames/rotations; can still terminate if *all* files vanish
  # We'll let Ctrl+C stop it; otherwise it runs until tail exits.
  tail -F "${LOG_FILES[@]}" 2>/dev/null | awk -v IGNORECASE=1 -v are="$ALERT_RE" -v ire="$INFO_RE" '
    $0 ~ are { printf "[ALERT] %s\n", $0; fflush(); next }
    $0 ~ ire { printf "[INFO]  %s\n", $0; fflush(); next }
    { print $0; fflush() }
  '
else
  tail -F "${LOG_FILES[@]}" 2>/dev/null
fi
