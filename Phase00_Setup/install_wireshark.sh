#!/usr/bin/env bash
set -euo pipefail

################################################################################
#            Script to Install Wireshark on Kali Linux                        #
################################################################################

SCRIPT_NAME="$(basename "$0")"

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: Run with sudo:"
  echo "  sudo ./${SCRIPT_NAME}"
  exit 1
fi

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
apt update -y

# Step 2: Install Wireshark
echo_step "Step 2: Installing Wireshark..."
apt install -y wireshark

# Step 3: Configure Wireshark for Non-Root Usage
echo_step "Step 3: Configuring Wireshark for Non-Root Usage..."
export DEBIAN_FRONTEND=noninteractive
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
