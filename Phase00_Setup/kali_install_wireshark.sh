#!/bin/bash

################################################################################
#            Script to Install Wireshark on Kali Linux                        #
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
echo -e "\e[1;104m                 WIRESHARK INSTALLATION SCRIPT\e[0m"
echo -e "\e[1;100m################################################################################\e[0m\n"

# Step 1: Update package lists
echo_step "Step 1: Updating Package Lists..."
apt update

# Step 2: Install Wireshark
echo_step "Step 2: Installing Wireshark..."
apt install -y wireshark

# Step 3: Configure Wireshark for Non-Root Usage
echo_step "Step 3: Configuring Wireshark for Non-Root Usage..."
dpkg-reconfigure wireshark-common
usermod -aG wireshark $USER

# Final message
echo -e "\e[1;100m################################################################################\e[0m"
echo -e "\e[1;102m  Installation Complete: Reboot to Apply Group Changes!  \e[0m"
echo -e "\e[1;100m################################################################################\e[0m"
