#!/bin/bash

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
    echo "[!] This script must be run as root. Please try again with 'sudo'."
    exit 1
fi

echo "=========================================================="
echo "           Terminal Command History Cleaner               "
echo "=========================================================="
echo "[*] Starting process to clear history and logs..."
echo

# Paths to history files
HISTORY_FILES=(
    "$HOME/.bash_history"        # User's shell history
    "/root/.bash_history"        # Root's shell history
    "/var/log/wtmp"              # Logins and logouts
    "/var/log/btmp"              # Failed login attempts
    "/var/log/lastlog"           # Last login info
    "/var/log/auth.log"          # Authentication logs
    "/var/log/syslog"            # System log
)

# Disable in-session history tracking
echo "[*] Disabling history tracking in this session..."
unset HISTFILE
export HISTSIZE=0
export HISTFILESIZE=0
echo "[+] History tracking disabled."

# Clear in-memory shell history
echo "[*] Clearing in-memory shell history..."
history -c
echo "[+] In-memory history cleared."

# Delete history and log files
echo "[*] Deleting history and log files securely..."
for FILE in "${HISTORY_FILES[@]}"; do
    if [[ -f $FILE ]]; then
        echo "[*] Processing $FILE..."
        shred -u -z $FILE 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo "[+] Successfully deleted $FILE."
        else
            echo "[!] Failed to delete $FILE. Check permissions or file status."
        fi
    else
        echo "[-] File $FILE not found. Skipping..."
    fi
done

# Restart logging services
echo
echo "[*] Restarting logging services..."
if systemctl restart rsyslog; then
    echo "[+] Logging services restarted successfully."
else
    echo "[!] Failed to restart logging services. Manual intervention may be required."
fi

# Additional step to remove shell history cache if applicable
echo "[*] Checking for additional history caches..."
if [[ -f /tmp/.bash_history ]]; then
    shred -u -z /tmp/.bash_history
    echo "[+] Removed temporary history cache at /tmp/.bash_history."
else
    echo "[-] No temporary history cache found in /tmp."
fi

# Final status
echo
echo "=========================================================="
echo "[*] All specified history and log files processed."
echo "[*] Terminal command history cleared securely."
echo "[*] Ensure no traces remain manually if necessary."
echo "=========================================================="

exit 0
