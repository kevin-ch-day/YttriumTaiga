#!/bin/bash

################################################################################
#            Kali Linux System Cleanup and Maintenance Script                #
#   This script performs system cleanup tasks such as autoremove, autoclean,  #
#   clearing unused files, fixing permissions, and optimizing disk space.     #
################################################################################

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display messages with enhanced formatting
echo_step() {
  echo -e "\n\e[1;100m\e[1;97m==============================================\e[0m"
  echo -e "\e[1;104m\e[1;97m$1\e[0m"
  echo -e "\e[1;100m\e[1;97m==============================================\e[0m\n"
}

# Display header
echo -e "\e[1;100m################################################################################\e[0m"
echo -e "\e[1;104m            KALI LINUX SYSTEM CLEANUP AND MAINTENANCE SCRIPT\e[0m"
echo -e "\e[1;100m################################################################################\e[0m\n"

# Step 1: Autoremove unnecessary packages
echo_step "Step 1: Removing Unnecessary Packages (apt autoremove)..."
apt autoremove -y || echo -e "\e[1;91mFailed to autoremove packages.\e[0m"

# Step 2: Autoclean to remove cached files
echo_step "Step 2: Cleaning Up Cached Package Files (apt autoclean)..."
apt autoclean -y || echo -e "\e[1;91mFailed to autoclean packages.\e[0m"

# Step 3: Clear the APT cache
echo_step "Step 3: Removing All Cached Package Files..."
apt clean -y || echo -e "\e[1;91mFailed to clean APT cache.\e[0m"

# Step 4: Remove old log files with better permissions handling
echo_step "Step 4: Clearing Old Log Files..."
find /var/log -type f -name "*.log" -exec sh -c 'truncate -s 0 "$1" 2>/dev/null || echo -e "\e[1;93mSkipped (permission denied): $1\e[0m"' _ {} \;
echo -e "\e[1;92mLog files have been cleared!\e[0m"

# Step 5: Fix potential permission issues
echo_step "Step 5: Fixing File and Directory Permissions..."
chmod -R o-rwx /var/log || echo -e "\e[1;91mFailed to update permissions for /var/log.\e[0m"

# Step 6: Check disk usage
echo_step "Step 6: Checking Disk Usage..."
df -h | grep -E '^Filesystem|/dev/' || echo -e "\e[1;91mFailed to fetch disk usage information.\e[0m"

# Step 7: Remove orphaned packages
echo_step "Step 7: Removing Orphaned Packages..."
deborphan | xargs -r apt remove -y || echo -e "\e[1;93mNo orphaned packages found.\e[0m"

# Final message
echo -e "\e[1;100m################################################################################\e[0m"
echo -e "\e[1;102m  System Cleanup Complete: Your System is Optimized and Secure!  \e[0m"
echo -e "\e[1;100m################################################################################\e[0m"
