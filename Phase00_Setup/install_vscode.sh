#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: install_vscode.sh
# Purpose : Install Visual Studio Code (Microsoft repo) on Kali Linux
# Run     : sudo ./install_vscode.sh
# Log     : ./logs/install_vscode.log (no timestamp)
#
# Notes:
# - Uses a modern keyring + "signed-by" (avoids deprecated apt-key).
# - Creates logs/ and log file as "shared" (not sudo-locked):
#     logs/ mode 1777 (shared + sticky, like /tmp)
#     log file mode 0666 (all users can read/append)
# ============================================================

LOG_MODE="${LOG_MODE:-append}"   # append|overwrite

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: run with sudo:"
  echo "  sudo ./$(basename "$0")"
  exit 1
fi

# ---- Shared output directory helpers ----
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
LOG_FILE="${LOG_DIR}/install_vscode.log"

ensure_shared_dir "${LOG_DIR}"
ensure_shared_file "${LOG_FILE}"

if [[ "${LOG_MODE}" == "overwrite" ]]; then
  : > "${LOG_FILE}"
fi
ensure_shared_file "${LOG_FILE}"

log() { printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${LOG_FILE}"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "ERROR: missing required command: $1"; exit 2; }
}

need_cmd apt-get
need_cmd apt-cache
need_cmd dpkg
need_cmd curl
need_cmd gpg
need_cmd install

ARCH="$(dpkg --print-architecture)"
log "== VS Code installer (Kali) =="
log "Detected architecture: ${ARCH}"

# Microsoft repo supports amd64 and arm64 (and often armhf). We’ll allow these.
case "${ARCH}" in
  amd64|arm64|armhf) ;;
  *)
    log "ERROR: Unsupported architecture for this installer: ${ARCH}"
    log "If you still want VS Code, consider downloading the .deb manually from Microsoft."
    exit 3
    ;;
esac

log "Installing prerequisites..."
apt-get update -y 2>&1 | tee -a "${LOG_FILE}"
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  apt-transport-https \
  2>&1 | tee -a "${LOG_FILE}"

# Keyring + repo config
KEYRING_DIR="/etc/apt/keyrings"
KEYRING_PATH="${KEYRING_DIR}/microsoft.gpg"
REPO_LIST="/etc/apt/sources.list.d/vscode.list"
MS_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
VSCODE_REPO_URL="https://packages.microsoft.com/repos/vscode"

log "Setting up Microsoft keyring..."
mkdir -p "${KEYRING_DIR}"
chmod 0755 "${KEYRING_DIR}" || true

# Download and dearmor key into keyring location
curl -fsSL "${MS_KEY_URL}" | gpg --dearmor -o "${KEYRING_PATH}"
chmod 0644 "${KEYRING_PATH}"

log "Writing VS Code apt repo..."
# Keep it explicit and signed-by pinned to the keyring file
cat > "${REPO_LIST}" <<EOF
deb [arch=${ARCH} signed-by=${KEYRING_PATH}] ${VSCODE_REPO_URL} stable main
EOF
chmod 0644 "${REPO_LIST}"

log "Updating apt package lists (with VS Code repo)..."
apt-get update -y 2>&1 | tee -a "${LOG_FILE}"

log "Installing VS Code package: code"
apt-get install -y code 2>&1 | tee -a "${LOG_FILE}"

log "Verifying install..."
if command -v code >/dev/null 2>&1; then
  log "SUCCESS: $(code --version | head -n 1 || true)"
  log "Launch from terminal: code"
else
  log "ERROR: 'code' command not found after install."
  exit 4
fi

log "Done."
