#!/usr/bin/env bash
# filename: setup_git.sh
set -euo pipefail

# ============================================================
# Kali Event-Day Git Setup (standalone)
# Version : 0.2.0
#
# Goals:
# - Install git if missing (apt)
# - Configure global identity (user.name / user.email)
# - Set safe default behaviors for event-day workflows
# - Optional SSH key generation + agent add (non-destructive)
#
# Usage:
#   sudo ./setup_git.sh
#
# Options (env vars):
#   GIT_USERNAME="..."          # default: kevin-ch-day
#   GIT_EMAIL="..."             # default: kevinday612-softwaredev@outlook.com
#   GIT_DEFAULT_BRANCH="main"   # default: main
#   GIT_CREATE_SSH_KEY=0|1      # default: 0
#   LOG_MODE=append|overwrite   # default: append
#
# Log:
#   ./logs/setup_git.log  (no timestamp)
# ============================================================

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: Run with sudo:"
  echo "  sudo ./setup_git.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/setup_git.log"

LOG_MODE="${LOG_MODE:-append}"
GIT_USERNAME="${GIT_USERNAME:-kevin-ch-day}"
GIT_EMAIL="${GIT_EMAIL:-kevinday612-softwaredev@outlook.com}"
GIT_DEFAULT_BRANCH="${GIT_DEFAULT_BRANCH:-main}"
GIT_CREATE_SSH_KEY="${GIT_CREATE_SSH_KEY:-0}"

mkdir -p "$LOG_DIR"

if [[ "$LOG_MODE" == "overwrite" ]]; then
  : > "$LOG_FILE"
else
  touch "$LOG_FILE"
fi

log() {
  local msg="$*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
  log "WARN: $*"
}

section() {
  log ""
  log "============================================================"
  log "$*"
  log "============================================================"
}

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

apt_install_git() {
  section "Installing Git"
  if need_cmd git; then
    log "[*] git already installed: $(git --version 2>/dev/null || true)"
    return 0
  fi

  log "[*] Updating apt + installing git..."
  apt-get update -y >>"$LOG_FILE" 2>&1
  apt-get install -y git >>"$LOG_FILE" 2>&1

  if ! need_cmd git; then
    warn "Git install failed (git not found after install)."
    return 1
  fi

  log "[*] Git installed: $(git --version 2>/dev/null || true)"
  return 0
}

show_git_config() {
  section "Current Global Git Config"

  local u e b
  u="$(git config --global user.name 2>/dev/null || true)"
  e="$(git config --global user.email 2>/dev/null || true)"
  b="$(git config --global init.defaultBranch 2>/dev/null || true)"

  log "[*] user.name          : ${u:-<not set>}"
  log "[*] user.email         : ${e:-<not set>}"
  log "[*] init.defaultBranch : ${b:-<not set>}"
}

set_git_identity() {
  section "Configuring Global Git Identity"

  if [[ -z "$GIT_USERNAME" || -z "$GIT_EMAIL" ]]; then
    warn "GIT_USERNAME or GIT_EMAIL empty; refusing to configure identity."
    warn "Set env vars: GIT_USERNAME=... GIT_EMAIL=..."
    return 1
  fi

  git config --global user.name "$GIT_USERNAME"
  git config --global user.email "$GIT_EMAIL"

  log "[*] Set user.name  = $GIT_USERNAME"
  log "[*] Set user.email = $GIT_EMAIL"
}

set_git_sane_defaults() {
  section "Setting Event-Day Sane Defaults"

  # Default initial branch name
  git config --global init.defaultBranch "$GIT_DEFAULT_BRANCH"
  log "[*] Set init.defaultBranch = $GIT_DEFAULT_BRANCH"

  # Helpful defaults
  git config --global pull.rebase false
  git config --global fetch.prune true
  git config --global advice.detachedHead false
  log "[*] Set pull.rebase=false, fetch.prune=true, advice.detachedHead=false"

  # Safer line endings (avoid Windows/Kali churn if repo is shared)
  # input = convert CRLF->LF on commit, keep LF in repo
  git config --global core.autocrlf input
  log "[*] Set core.autocrlf=input"

  # Better diffs for common file types (optional)
  git config --global diff.colorMoved zebra || true
  log "[*] Set diff.colorMoved=zebra (if supported)"
}

maybe_create_ssh_key() {
  section "SSH Key (Optional)"

  if [[ "$GIT_CREATE_SSH_KEY" != "1" ]]; then
    log "[*] Skipping SSH key creation (set GIT_CREATE_SSH_KEY=1 to enable)."
    return 0
  fi

  if ! need_cmd ssh-keygen; then
    warn "ssh-keygen not found; install openssh-client."
    return 1
  fi

  local key_path="/home/${SUDO_USER}/.ssh/id_ed25519"
  local pub_path="${key_path}.pub"

  if [[ -f "$key_path" && -f "$pub_path" ]]; then
    log "[*] SSH key already exists: $key_path"
    log "[*] Public key:"
    cat "$pub_path" | tee -a "$LOG_FILE" >/dev/null || true
    return 0
  fi

  # Ensure .ssh exists with correct perms
  local ssh_dir="/home/${SUDO_USER}/.ssh"
  mkdir -p "$ssh_dir"
  chown "${SUDO_USER}:${SUDO_USER}" "$ssh_dir"
  chmod 700 "$ssh_dir"

  log "[*] Creating new SSH key (ed25519) at: $key_path"
  sudo -u "$SUDO_USER" ssh-keygen -t ed25519 -f "$key_path" -N "" -C "$GIT_EMAIL" >>"$LOG_FILE" 2>&1

  if [[ -f "$pub_path" ]]; then
    log "[*] SSH public key created:"
    cat "$pub_path" | tee -a "$LOG_FILE" >/dev/null || true
  else
    warn "SSH key generation failed."
    return 1
  fi
}

main() {
  section "Kali Git Setup شروع"
  log "[*] Time: $(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"
  log "[*] Script: $0"
  log "[*] User: ${SUDO_USER:-root}"
  log "[*] Host: $(hostname 2>/dev/null || echo unknown)"
  log "[*] Log:  $LOG_FILE"

  apt_install_git
  show_git_config
  set_git_identity
  set_git_sane_defaults
  maybe_create_ssh_key
  show_git_config

  section "Done"
  log "[*] Git is ready for event day."
}

main "$@"
