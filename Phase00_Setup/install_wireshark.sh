#!/usr/bin/env bash
set -euo pipefail

################################################################################
#            Script to Install Wireshark on Kali Linux                        #
################################################################################

SCRIPT_NAME="$(basename "$0")"
LOG_MODE="${LOG_MODE:-append}"   # append|overwrite

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: Run with sudo:"
  echo "  sudo ./${SCRIPT_NAME}"
  exit 1
fi

# ---- Shared log helpers (match other install scripts) ----
ensure_shared_dir() {
  local d="$1"
  mkdir -p "$d"
  chmod 1777 "$d" || true
}

ensure_shared_file() {
  local f="$1"
  ensure_shared_dir "$(dirname "$f")"
  touch "$f"
  chmod 0666 "$f" || true
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/install_wireshark.log"

ensure_shared_dir "${LOG_DIR}"
ensure_shared_file "${LOG_FILE}"

if [[ "${LOG_MODE}" == "overwrite" ]]; then
  : > "${LOG_FILE}"
fi
ensure_shared_file "${LOG_FILE}"

log() { printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${LOG_FILE}"; }

# Function to display messages with enhanced formatting
echo_step() {
  echo -e "\n\e[1;100m\e[1;97m==============================================\e[0m"
  echo -e "\e[1;104m\e[1;97m$1\e[0m"
  echo -e "\e[1;100m\e[1;97m==============================================\e[0m\n"
}

# Display header
echo -e "\e[1;100m################################################################################\e[0m"
echo -e "\e[1;104m                 WIRESHARK INSTALLATION SCRIPT\e[0m"
echo -e "\e[1;100m################################################################################\e[0m\n"

# Step 1: Update package lists
echo_step "Step 1: Updating Package Lists..."
log "Updating package lists..."
apt-get update -y 2>&1 | tee -a "${LOG_FILE}"

# Step 2: Install Wireshark
echo_step "Step 2: Installing Wireshark..."
log "Installing Wireshark..."
apt-get install -y wireshark 2>&1 | tee -a "${LOG_FILE}"

# Step 3: Configure Wireshark for Non-Root Usage
echo_step "Step 3: Configuring Wireshark for Non-Root Usage..."
export DEBIAN_FRONTEND=noninteractive
command -v debconf-set-selections >/dev/null 2>&1 || {
  echo "ERROR: debconf-set-selections not found (install debconf-utils)"
  exit 2
}
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
dpkg-reconfigure -f noninteractive wireshark-common
TARGET_USER="${SUDO_USER:-$USER}"
usermod -aG wireshark "$TARGET_USER"

# Fix ownership if run via sudo so logs/history aren't root-owned
if [[ -n "${SUDO_USER:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  chown -R "${SUDO_USER}:${SUDO_USER}" "$SCRIPT_DIR" 2>/dev/null || true
fi

# Final message
echo -e "\e[1;100m################################################################################\e[0m"
echo -e "\e[1;102m  Installation Complete: Reboot to Apply Group Changes!  \e[0m"
echo -e "\e[1;100m################################################################################\e[0m"
