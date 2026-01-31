#!/bin/bash

################################################################################
#              Kali Linux Service Checker and Monitor Script                  #
#   A professional script to list and display all active and inactive         #
#   services, helping you monitor and manage your system efficiently.         #
################################################################################

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display messages with enhanced formatting
echo_step() {
  echo -e "\n\e[1;100m\e[1;97m==============================================\e[0m"
  echo -e "\e[1;104m\e[1;97m$1\e[0m"
  echo -e "\e[1;100m\e[1;97m==============================================\e[0m\n"
}

# Function to display table headers
echo_table_header() {
  echo -e "\e[1;96m%-40s %-10s\e[0m" "SERVICE NAME" "STATUS"
  echo -e "\e[1;94m---------------------------------------- ----------\e[0m"
}

# Display header
echo -e "\e[1;100m################################################################################\e[0m"
echo -e "\e[1;104m           KALI LINUX SERVICE CHECKER AND MONITOR SCRIPT\e[0m"
echo -e "\e[1;100m################################################################################\e[0m\n"

# Display all currently running services
echo_step "Step 1: Listing All Active Services..."
echo_table_header
active_services=$(systemctl list-units --type=service --state=running | awk '{printf "%-40s %-10s\n", $1, $4}')
echo -e "$active_services"

# Display all inactive services
echo_step "Step 2: Listing All Inactive Services..."
echo_table_header
inactive_services=$(systemctl list-units --type=service --state=inactive | awk '{printf "%-40s %-10s\n", $1, $4}')
echo -e "$inactive_services"

# Provide summary of service counts
echo_step "Step 3: Service Summary..."
active_count=$(echo "$active_services" | grep -c ".service")
inactive_count=$(echo "$inactive_services" | grep -c ".service")

echo -e "\e[1;106m\e[1;30m==============================================\e[0m"
echo -e "\e[1;102m\e[1;30mTotal Active Services: $active_count\e[0m"
echo -e "\e[1;101m\e[1;30mTotal Inactive Services: $inactive_count\e[0m"
echo -e "\e[1;106m\e[1;30m==============================================\e[0m\n"

# Highlight critical inactive services (if any)
echo_step "Step 4: Highlighting Critical Inactive Services..."
critical_services=("ssh.service" "nginx.service" "mysql.service")
for service in "${critical_services[@]}"; do
  if systemctl is-enabled "$service" &> /dev/null && ! systemctl is-active "$service" &> /dev/null; then
    echo -e "\e[1;101m\e[1;97mCRITICAL: $service is inactive!\e[0m"
  else
    echo -e "\e[1;102m\e[1;30mOK: $service is active\e[0m"
  fi
done

# Final message
echo -e "\e[1;100m################################################################################\e[0m"
echo -e "\e[1;102m  Service Check Complete: Stay in Control of Your System!\e[0m"
echo -e "\e[1;100m################################################################################\e[0m"