#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: kali_install_chrome.sh
# Purpose : Install Google Chrome (stable) on Kali Linux
# Run     : sudo ./kali_install_chrome.sh
# Log     : ./logs/kali_install_chrome.log  (no timestamp)
#
# Goals:
# - Works on Kali rolling snapshots (optional deps may not exist)
# - Creates logs/ and log file as "shared" (not sudo-locked)
#   * logs/ gets mode 1777 (shared + sticky, like /tmp)
#   * log file gets mode 0666 (all users can read/append)
# ============================================================

LOG_MODE="${LOG_MODE:-append}"   # append|overwrite
ARCH="$(dpkg --print-architecture)"

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: run with sudo:"
  echo "  sudo $0"
  exit 1
fi

if [[ "${ARCH}" != "amd64" ]]; then
  echo "ERROR: Google Chrome .deb from Google is typically amd64 only."
  echo "Detected architecture: ${ARCH}"
  echo "If you need ARM support, consider Chromium instead."
  exit 2
fi

# ---- Shared output directory helpers ----
# Goal: dirs/files we create should be usable by ALL users (even if run via sudo).
# Using a sticky shared dir mode (1777), like /tmp:
# - Anyone can write
# - Users cannot delete/rename other users' files in that directory
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
LOG_FILE="${LOG_DIR}/kali_install_chrome.log"

ensure_shared_dir "${LOG_DIR}"
ensure_shared_file "${LOG_FILE}"

if [[ "${LOG_MODE}" == "overwrite" ]]; then
  : > "${LOG_FILE}"
fi
ensure_shared_file "${LOG_FILE}"

log() { printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${LOG_FILE}"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "ERROR: missing required command: $1"; exit 3; }
}

apt_install() {
  local pkgs=("$@")
  apt-get install -y --no-install-recommends "${pkgs[@]}" 2>&1 | tee -a "${LOG_FILE}"
}

apt_install_if_available() {
  local pkgs=("$@")
  local to_install=()

  for p in "${pkgs[@]}"; do
    if apt-cache show "$p" >/dev/null 2>&1; then
      to_install+=("$p")
    else
      log "Skipping optional package not found in repos: $p"
    fi
  done

  if ((${#to_install[@]})); then
    apt_install "${to_install[@]}"
  fi
}

need_cmd apt-get
need_cmd dpkg
need_cmd apt-cache

log "== Chrome installer (Kali) =="

log "Updating apt package lists..."
apt-get update -y 2>&1 | tee -a "${LOG_FILE}"

log "Installing required prerequisites..."
apt_install \
  ca-certificates \
  curl \
  wget \
  gnupg \
  xdg-utils \
  fonts-liberation

log "Installing optional helpers (skip if unavailable on this Kali snapshot)..."
apt_install_if_available \
  libu2f-udev \
  libu2f-host0 \
  libfido2-1

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

DEB_PATH="${TMP_DIR}/google-chrome-stable_current_amd64.deb"
CHROME_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

log "Downloading Chrome .deb from Google..."
curl -fsSL "${CHROME_URL}" -o "${DEB_PATH}"

log "Installing .deb (dpkg)..."
set +e
dpkg -i "${DEB_PATH}" 2>&1 | tee -a "${LOG_FILE}"
DPKG_RC="${PIPESTATUS[0]}"
set -e

if [[ "${DPKG_RC}" -ne 0 ]]; then
  log "dpkg reported missing dependencies; running apt-get -f install..."
  apt-get -f install -y 2>&1 | tee -a "${LOG_FILE}"
fi

log "Verifying install..."
if command -v google-chrome >/dev/null 2>&1; then
  log "SUCCESS: $(google-chrome --version || true)"
  log "Launch with: google-chrome"
else
  log "ERROR: google-chrome not found after install."
  exit 4
fi

log "Done."

