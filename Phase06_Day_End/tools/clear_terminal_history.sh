#!/bin/bash

# Description: This script securely clears terminal history for both bash and zsh shells.

CONFIRM="${CONFIRM:-0}"
if [[ "$CONFIRM" != "1" ]]; then
    echo "[!] WARNING: This will clear shell history for this user."
    if [[ $EUID -eq 0 ]]; then
        echo "[!] You are root. This will clear root's history, not your user history."
    fi
    if [[ -t 0 ]]; then
        read -r -p "Type CLEAR to proceed: " ans
        if [[ "$ans" != "CLEAR" ]]; then
            echo "[*] Aborted."
            exit 1
        fi
    else
        echo "[!] Non-interactive shell. Re-run with CONFIRM=1 to proceed."
        exit 1
    fi
fi

# Function to securely clear bash history
clear_bash_history() {
    if [ -f ~/.bash_history ]; then
        echo "[*] Clearing bash history..."
        history -c                      # Clear current session history
        > ~/.bash_history               # Empty the bash history file
        history -w                      # Rewrite the history file to ensure it's clean
        echo "[+] Bash history cleared successfully."
    else
        echo "[-] Bash history file not found. Skipping..."
    fi
}

# Function to securely clear zsh history
clear_zsh_history() {
    if [ -f ~/.zsh_history ]; then
        echo "[*] Clearing zsh history..."
        history -c                      # Clear current session history
        > ~/.zsh_history                # Empty the zsh history file
        echo "[+] ZSH history cleared successfully."
    else
        echo "[-] ZSH history file not found. Skipping..."
    fi
}

# Clear terminal history for both bash and zsh
echo "Starting terminal history cleanup..."
clear_bash_history
clear_zsh_history

# Enhanced feedback
echo "[+] All terminal history cleared. To ensure no traces remain, restart your terminal session."
