#!/bin/bash

# Description: This script securely clears terminal history for both bash and zsh shells.

# Function to securely clear bash history
clear_bash_history() {
    if [ -f ~/.bash_history ]; then
        echo "[*] Clearing bash history..."
        history -c                      # Clear current session history
        > ~/.bash_history               # Empty the bash history file
        history -w                      # Rewrite the history file to ensure it’s clean
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
