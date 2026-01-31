#!/usr/bin/env bash
# filename: setup_git.sh
set -euo pipefail

# ============================================================
# Kali Event-Day Git Setup (standalone)
# Version : 0.4.0
#
# Goals:
# - Install git if missing (apt)
# - Configure GLOBAL identity (user.name / user.email) for the NON-ROOT user
#   (when run via sudo, write to SUDO_USER's ~/.gitconfig, not root's)
# - Add "event-day" defaults that prevent common friction in VS Code + CLI
# - Optional: SSH key generation
# - Optional: credential helper (cache) so HTTPS pushes don't re-prompt constantly
# - Optional: global .gitignore (OS junk, .vscode, __pycache__, etc.)
#
# Usage:
#   sudo ./setup_git.sh
#
# Options (env vars):
#   GIT_USERNAME="..."                 # default: kevin-ch-day
#   GIT_EMAIL="..."                    # default: kevinday612-softwaredev@outlook.com
#   GIT_DEFAULT_BRANCH="main"          # default: main
#   GIT_CREATE_SSH_KEY=0|1             # default: 0
#   GIT_ENABLE_CRED_CACHE=0|1          # default: 1 (cache HTTPS creds for 8h)
#   GIT_CRED_CACHE_TIMEOUT_SECS=28800  # default: 28800 (8 hours)
#   GIT_SET_EDITOR=0|1                 # default: 1 (set editor to code if available)
#   GIT_CREATE_GLOBAL_GITIGNORE=0|1    # default: 1
#   GIT_ADD_SAFE_DIRECTORY=0|1         # default: 0  (set to 1 if you hit "dubious ownership")
#   SAFE_DIRECTORY_PATH="/path"        # used when GIT_ADD_SAFE_DIRECTORY=1
#   LOG_MODE=append|overwrite          # default: append
#
# Log:
#   ./logs/setup_git.log  (no timestamp)
# ============================================================

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: Run with sudo:"
  echo "  sudo ./setup_git.sh"
  exit 1
fi

TARGET_USER="${SUDO_USER:-root}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/setup_git.log"

LOG_MODE="${LOG_MODE:-append}"
GIT_USERNAME="${GIT_USERNAME:-kevin-ch-day}"
GIT_EMAIL="${GIT_EMAIL:-kevinday612-softwaredev@outlook.com}"
GIT_DEFAULT_BRANCH="${GIT_DEFAULT_BRANCH:-main}"

GIT_CREATE_SSH_KEY="${GIT_CREATE_SSH_KEY:-0}"
GIT_ENABLE_CRED_CACHE="${GIT_ENABLE_CRED_CACHE:-1}"
GIT_CRED_CACHE_TIMEOUT_SECS="${GIT_CRED_CACHE_TIMEOUT_SECS:-28800}"

GIT_SET_EDITOR="${GIT_SET_EDITOR:-1}"
GIT_CREATE_GLOBAL_GITIGNORE="${GIT_CREATE_GLOBAL_GITIGNORE:-1}"

GIT_ADD_SAFE_DIRECTORY="${GIT_ADD_SAFE_DIRECTORY:-0}"
SAFE_DIRECTORY_PATH="${SAFE_DIRECTORY_PATH:-}"

# ---- Shared output directory helpers (not sudo-locked) ----
# logs/ mode 1777 (shared + sticky, like /tmp)
# log file mode 0666 (everyone can read/append)
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

ensure_shared_dir "${LOG_DIR}"
ensure_shared_file "${LOG_FILE}"
if [[ "${LOG_MODE}" == "overwrite" ]]; then : > "${LOG_FILE}"; fi
ensure_shared_file "${LOG_FILE}"

log() { printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${LOG_FILE}"; }
section() { log ""; log "============================================================"; log "$*"; log "============================================================"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || { log "ERROR: missing required command: $1"; exit 2; }; }

# Run git as the target user with correct HOME.
git_as_target() {
  if [[ "${TARGET_USER}" == "root" ]]; then
    git "$@"
  else
    sudo -u "${TARGET_USER}" -H git "$@"
  fi
}

# Resolve target HOME robustly
target_home() {
  if [[ "${TARGET_USER}" == "root" ]]; then
    echo "/root"
  else
    # getent is best; fallback to /home/user
    if command -v getent >/dev/null 2>&1; then
      getent passwd "${TARGET_USER}" | cut -d: -f6
    else
      echo "/home/${TARGET_USER}"
    fi
  fi
}

apt_install_git() {
  section "Installing Git (if needed)"
  if command -v git >/dev/null 2>&1; then
    log "[*] Git already installed: $(git --version 2>/dev/null || true)"
    return 0
  fi
  need_cmd apt-get
  log "[*] apt-get update..."
  apt-get update -y 2>&1 | tee -a "${LOG_FILE}"
  log "[*] apt-get install git..."
  apt-get install -y git 2>&1 | tee -a "${LOG_FILE}"
  log "[*] Git installed: $(git --version 2>/dev/null || true)"
}

show_git_config() {
  section "Current Global Git Config (Target User)"
  log "[*] Target user: ${TARGET_USER}"
  log "[*] HOME: $(target_home)"

  local u e b ed
  u="$(git_as_target config --global user.name 2>/dev/null || true)"
  e="$(git_as_target config --global user.email 2>/dev/null || true)"
  b="$(git_as_target config --global init.defaultBranch 2>/dev/null || true)"
  ed="$(git_as_target config --global core.editor 2>/dev/null || true)"

  log "[*] user.name          : ${u:-<not set>}"
  log "[*] user.email         : ${e:-<not set>}"
  log "[*] init.defaultBranch : ${b:-<not set>}"
  log "[*] core.editor        : ${ed:-<not set>}"
}

set_git_identity() {
  section "Configuring Global Git Identity (Target User)"
  local cur_name cur_email
  cur_name="$(git_as_target config --global user.name 2>/dev/null || true)"
  cur_email="$(git_as_target config --global user.email 2>/dev/null || true)"

  if [[ -n "${cur_name}" && -n "${cur_email}" ]]; then
    log "[*] Identity already set for ${TARGET_USER}; leaving as-is."
    log "[*] user.name  = ${cur_name}"
    log "[*] user.email = ${cur_email}"
    return 0
  fi

  if [[ -z "${GIT_USERNAME}" || -z "${GIT_EMAIL}" ]]; then
    log "ERROR: GIT_USERNAME or GIT_EMAIL is empty. Refusing to set identity."
    exit 3
  fi

  git_as_target config --global user.name "${GIT_USERNAME}"
  git_as_target config --global user.email "${GIT_EMAIL}"

  log "[*] Set user.name  = ${GIT_USERNAME}"
  log "[*] Set user.email = ${GIT_EMAIL}"
}

set_git_sane_defaults() {
  section "Setting Event-Day Sane Defaults (Target User)"

  git_as_target config --global init.defaultBranch "${GIT_DEFAULT_BRANCH}"
  log "[*] Set init.defaultBranch = ${GIT_DEFAULT_BRANCH}"

  # Helpful defaults
  git_as_target config --global pull.rebase false
  git_as_target config --global fetch.prune true
  git_as_target config --global core.autocrlf input
  git_as_target config --global rerere.enabled true
  git_as_target config --global diff.colorMoved zebra
  git_as_target config --global branch.sort -committerdate

  log "[*] Set pull.rebase = false"
  log "[*] Set fetch.prune = true"
  log "[*] Set core.autocrlf = input"
  log "[*] Set rerere.enabled = true"
  log "[*] Set diff.colorMoved = zebra"
  log "[*] Set branch.sort = -committerdate"

  # Small quality-of-life aliases
  git_as_target config --global alias.st "status -sb"
  git_as_target config --global alias.lg "log --oneline --decorate --graph --all"
  git_as_target config --global alias.unstage "restore --staged --"
  git_as_target config --global alias.last "log -1 --stat"
  log "[*] Added aliases: st, lg, unstage, last"
}

set_editor_if_possible() {
  section "Setting default Git editor (optional)"
  if [[ "${GIT_SET_EDITOR}" != "1" ]]; then
    log "[*] Skipping editor setup (GIT_SET_EDITOR=0)."
    return 0
  fi

  # Prefer VS Code if present for the target user; otherwise nano.
  if [[ "${TARGET_USER}" == "root" ]]; then
    if command -v code >/dev/null 2>&1; then
      git config --global core.editor "code --wait"
      log "[*] Set core.editor = code --wait"
      return 0
    fi
  else
    if sudo -u "${TARGET_USER}" -H bash -lc 'command -v code >/dev/null 2>&1'; then
      git_as_target config --global core.editor "code --wait"
      log "[*] Set core.editor = code --wait"
      return 0
    fi
  fi

  # Fallback
  if command -v nano >/dev/null 2>&1; then
    git_as_target config --global core.editor "nano"
    log "[*] Set core.editor = nano (fallback)"
  else
    log "[*] No code/nano detected; leaving core.editor unchanged."
  fi
}

setup_credential_cache() {
  section "HTTPS credential helper (optional)"
  if [[ "${GIT_ENABLE_CRED_CACHE}" != "1" ]]; then
    log "[*] Skipping credential cache (GIT_ENABLE_CRED_CACHE=0)."
    return 0
  fi

  # This caches HTTPS credentials in-memory for the given timeout.
  # Great for competitions; not permanent storage.
  git_as_target config --global credential.helper "cache --timeout=${GIT_CRED_CACHE_TIMEOUT_SECS}"
  log "[*] Set credential.helper = cache --timeout=${GIT_CRED_CACHE_TIMEOUT_SECS}"
}

create_global_gitignore() {
  section "Global .gitignore (optional)"
  if [[ "${GIT_CREATE_GLOBAL_GITIGNORE}" != "1" ]]; then
    log "[*] Skipping global gitignore (GIT_CREATE_GLOBAL_GITIGNORE=0)."
    return 0
  fi

  local home gi
  home="$(target_home)"
  gi="${home}/.config/git/ignore"

  # Create parent directory as the TARGET user so permissions are correct.
  if [[ "${TARGET_USER}" == "root" ]]; then
    mkdir -p "$(dirname "${gi}")"
  else
    sudo -u "${TARGET_USER}" -H mkdir -p "$(dirname "${gi}")"
  fi

  # Write a sensible ignore list (idempotent overwrite).
  local tmp
  tmp="$(mktemp)"
  cat > "${tmp}" <<'EOF'
# OS / editor junk
.DS_Store
Thumbs.db

# VS Code
.vscode/
*.code-workspace

# Python
__pycache__/
*.py[cod]
*.pyo
*.pyd
.pytest_cache/
.mypy_cache/
.venv/
venv/

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Archives / build artifacts
*.zip
*.tar
*.tar.gz
*.7z
dist/
build/

# Logs
*.log
logs/
EOF

  if [[ "${TARGET_USER}" == "root" ]]; then
    install -m 0644 "${tmp}" "${gi}"
  else
    install -m 0644 "${tmp}" "/tmp/ignore.$$"
    chown "${TARGET_USER}:${TARGET_USER}" "/tmp/ignore.$$"
    sudo -u "${TARGET_USER}" -H bash -lc "install -m 0644 /tmp/ignore.$$ '${gi}'"
    rm -f "/tmp/ignore.$$"
  fi
  rm -f "${tmp}"

  git_as_target config --global core.excludesfile "${gi}"
  log "[*] Wrote: ${gi}"
  log "[*] Set core.excludesfile = ${gi}"
}

add_safe_directory_if_requested() {
  section "Safe directory (optional)"
  if [[ "${GIT_ADD_SAFE_DIRECTORY}" != "1" ]]; then
    log "[*] Skipping safe.directory (GIT_ADD_SAFE_DIRECTORY=0)."
    return 0
  fi

  if [[ -z "${SAFE_DIRECTORY_PATH}" ]]; then
    log "ERROR: SAFE_DIRECTORY_PATH is empty but GIT_ADD_SAFE_DIRECTORY=1."
    log "Example: sudo GIT_ADD_SAFE_DIRECTORY=1 SAFE_DIRECTORY_PATH=/home/kali/myrepo ./setup_git.sh"
    exit 4
  fi

  git_as_target config --global --add safe.directory "${SAFE_DIRECTORY_PATH}"
  log "[*] Added safe.directory = ${SAFE_DIRECTORY_PATH}"
}

maybe_create_ssh_key() {
  section "Optional SSH Key Setup (Target User)"
  if [[ "${GIT_CREATE_SSH_KEY}" != "1" ]]; then
    log "[*] Skipping SSH key creation (GIT_CREATE_SSH_KEY=0)."
    return 0
  fi

  need_cmd ssh-keygen

  local home ssh_dir key_path
  home="$(target_home)"
  ssh_dir="${home}/.ssh"
  key_path="${ssh_dir}/id_ed25519"

  if [[ -f "${key_path}" ]]; then
    log "[*] SSH key already exists: ${key_path}"
    log "[*] Public key: ${key_path}.pub"
    return 0
  fi

  log "[*] Creating SSH key for ${TARGET_USER} at ${key_path} (no passphrase)..."
  if [[ "${TARGET_USER}" == "root" ]]; then
    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"
    ssh-keygen -t ed25519 -f "${key_path}" -N "" 2>&1 | tee -a "${LOG_FILE}"
  else
    sudo -u "${TARGET_USER}" -H bash -lc "mkdir -p '${ssh_dir}' && chmod 700 '${ssh_dir}'"
    sudo -u "${TARGET_USER}" -H ssh-keygen -t ed25519 -f "${key_path}" -N "" 2>&1 | tee -a "${LOG_FILE}"
  fi

  log "[*] Created: ${key_path}"
  log "[*] Public key: ${key_path}.pub"
  log "[*] Tip: Add the public key to GitHub/GitLab if you use SSH remotes."
}

quick_self_test() {
  section "Quick self-test (target user)"
  log "[*] git version: $(git --version 2>/dev/null || true)"
  log "[*] user.name : $(git_as_target config --global user.name 2>/dev/null || echo '<not set>')"
  log "[*] user.email: $(git_as_target config --global user.email 2>/dev/null || echo '<not set>')"

  # If inside a repo, show status as the target user (helps catch permission oddities)
  if [[ -d ".git" ]]; then
    log "[*] Repo detected in current directory; running git status..."
    git_as_target status -sb 2>&1 | tee -a "${LOG_FILE}" || true
  else
    log "[*] No .git directory in current working directory; skipping repo status."
  fi
}

main() {
  section "Git Setup start"
  log "[*] Target user: ${TARGET_USER}"
  log "[*] Log: ${LOG_FILE}"

  apt_install_git
  show_git_config
  set_git_identity
  set_git_sane_defaults
  set_editor_if_possible
  setup_credential_cache
  create_global_gitignore
  add_safe_directory_if_requested
  maybe_create_ssh_key
  show_git_config
  quick_self_test

  section "Done"
  log "[*] Git is ready."
}

main "$@"
