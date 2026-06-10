#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/Scripts/ccdc_common.sh"

################################################################################
#            Kali Linux System Cleanup and Maintenance Script                #
#   This script performs system cleanup tasks such as autoremove, autoclean,  #
#   clearing unused files, fixing permissions, and optimizing disk space.     #
################################################################################

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
  ccdc_die "$CCDC_E_USAGE" "This script must be run as root. Please try again with 'sudo'."
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Safety confirmation (avoid accidental cleanup)
CONFIRM="${CONFIRM:-0}"
if [[ "$CONFIRM" != "1" ]]; then
  echo "WARNING: This cleanup removes packages and truncates logs."
  if [[ -t 0 ]]; then
    read -r -p "Type CLEAN to proceed: " ans
    if [[ "$ans" != "CLEAN" ]]; then
      echo "Aborted."
      exit 1
    fi
  else
    echo "Non-interactive shell. Re-run with CONFIRM=1 to proceed."
    exit 1
  fi
fi

# Function to display messages with enhanced formatting
echo_step() {
  taconite_section "$1"
}

# Display header
taconite_header "Taconite System Cleanup" "Destructive end-of-day maintenance"

# Step 1: Autoremove unnecessary packages
echo_step "Step 1: Removing Unnecessary Packages (apt autoremove)..."
apt autoremove -y || taconite_fail "Failed to autoremove packages."

# Step 2: Autoclean to remove cached files
echo_step "Step 2: Cleaning Up Cached Package Files (apt autoclean)..."
apt autoclean -y || taconite_fail "Failed to autoclean packages."

# Step 3: Clear the APT cache
echo_step "Step 3: Removing All Cached Package Files..."
apt clean -y || taconite_fail "Failed to clean APT cache."

# Step 4: Remove old log files with better permissions handling
echo_step "Step 4: Clearing Old Log Files..."
find /var/log -type f -name "*.log" -exec sh -c 'truncate -s 0 "$1" 2>/dev/null || printf "[WARN] Skipped (permission denied): %s\n" "$1"' _ {} \;
taconite_ok "Log files have been cleared."

# Step 5: Fix potential permission issues
echo_step "Step 5: Fixing File and Directory Permissions..."
chmod -R o-rwx /var/log || taconite_fail "Failed to update permissions for /var/log."

# Step 6: Check disk usage
echo_step "Step 6: Checking Disk Usage..."
df -h | grep -E '^Filesystem|/dev/' || taconite_fail "Failed to fetch disk usage information."

# Step 7: Remove orphaned packages
echo_step "Step 7: Removing Orphaned Packages..."
if need_cmd deborphan; then
  deborphan | xargs -r apt remove -y || taconite_warn "No orphaned packages found."
else
  taconite_warn "deborphan not installed; skipping orphan removal."
fi

# Final message
taconite_section "System cleanup complete"
