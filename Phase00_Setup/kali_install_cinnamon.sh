#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: kali_install_cinnamon.sh
# Purpose : Install Cinnamon desktop environment on Kali Linux
# Run     : sudo ./kali_install_cinnamon.sh
# Notes   : Installs Cinnamon + LightDM, enables display manager
# Log     : ./logs/kali_install_cinnamon.log (no timestamp)
#
# Goals:
# - Avoid "sudo-locked" logs/output: logs/ is shared (1777) + log file (0666)
# - Be resilient on Kali rolling (some meta-packages vary)
# ============================================================

LOG_MODE="${LOG_MODE:-append}"              # append|overwrite
SET_DEFAULT_SESSION="${SET_DEFAULT_SESSION:-1}"  # 1=yes 0=no
DO_UPGRADE="${DO_UPGRADE:-1}"              # 1=yes 0=no  (upgrade can be slow/impactful on rolling)

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: run with sudo:"
  echo "  sudo $0"
  exit 1
fi

# ---- Shared output directory helpers ----
# Use sticky shared dir mode (1777), like /tmp:
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
LOG_FILE="${LOG_DIR}/kali_install_cinnamon.log"

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

apt_install() {
  # Strict install: fail if packages cannot be installed
  local pkgs=("$@")
  apt-get install -y --no-install-recommends "${pkgs[@]}" 2>&1 | tee -a "${LOG_FILE}"
}

apt_install_any() {
  # Try a list of packages; install the first one that exists
  # Usage: apt_install_any pkgA pkgB pkgC
  local p
  for p in "$@"; do
    if apt-cache show "$p" >/dev/null 2>&1; then
      log "Installing available package: $p"
      apt-get install -y --no-install-recommends "$p" 2>&1 | tee -a "${LOG_FILE}"
      return 0
    fi
    log "Not found (skipping): $p"
  done
  return 1
}

need_cmd apt-get
need_cmd systemctl
need_cmd dpkg
need_cmd apt-cache

log "== Cinnamon installer (Kali) =="

log "Updating apt package lists..."
apt-get update -y 2>&1 | tee -a "${LOG_FILE}"

if [[ "${DO_UPGRADE}" == "1" ]]; then
  log "Upgrading installed packages (conservative upgrade)..."
  apt-get -y upgrade 2>&1 | tee -a "${LOG_FILE}"
else
  log "Skipping upgrade (DO_UPGRADE=0)."
fi

log "Installing Xorg + D-Bus helper (baseline GUI deps)..."
apt_install xorg dbus-x11

log "Installing Cinnamon desktop environment..."
# Kali snapshots may differ; try common meta-packages first, then cinnamon itself.
set +e
apt_install_any cinnamon-desktop-environment cinnamon-core cinnamon || true
set -e

# Ensure at least the base cinnamon package is present
log "Ensuring Cinnamon base package is installed..."
apt-get install -y cinnamon 2>&1 | tee -a "${LOG_FILE}"

log "Installing a display manager (prefer LightDM)..."
# If lightdm isn't available for some reason, fall back to gdm3 (rare on Kali, but safe).
if ! apt_install_any lightdm gdm3; then
  log "ERROR: Could not install a display manager (lightdm/gdm3)."
  exit 3
fi

log "Installing a greeter (LightDM GTK greeter if using LightDM)..."
# This is optional; only install if package exists.
if apt-cache show lightdm-gtk-greeter >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends lightdm-gtk-greeter 2>&1 | tee -a "${LOG_FILE}"
else
  log "Skipping greeter package not found: lightdm-gtk-greeter"
fi

log "Enabling display manager to start at boot..."
# Enable whichever DM is installed
if systemctl list-unit-files | grep -q '^lightdm\.service'; then
  systemctl enable lightdm 2>&1 | tee -a "${LOG_FILE}" || true
  log "Enabled: lightdm"
elif systemctl list-unit-files | grep -q '^gdm\.service'; then
  systemctl enable gdm 2>&1 | tee -a "${LOG_FILE}" || true
  log "Enabled: gdm"
else
  log "WARNING: Could not detect display manager unit to enable."
fi

if [[ "${SET_DEFAULT_SESSION}" == "1" ]]; then
  log "Setting Cinnamon as the default session (best-effort)..."

  # Best-effort update-alternatives
  if command -v update-alternatives >/dev/null 2>&1 && [[ -x /usr/bin/cinnamon-session ]]; then
    update-alternatives --set x-session-manager /usr/bin/cinnamon-session 2>/dev/null || true
  fi

  # If LightDM is used, set default session.
  if [[ -d /etc/lightdm ]]; then
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat >/etc/lightdm/lightdm.conf.d/50-default-session.conf <<'EOF'
[Seat:*]
user-session=cinnamon
EOF
    log "Wrote: /etc/lightdm/lightdm.conf.d/50-default-session.conf"
  else
    log "NOTE: /etc/lightdm not present; default session file not written."
  fi
else
  log "Default session not changed (SET_DEFAULT_SESSION=0)."
fi

log "Verifying installation..."
if dpkg -l | grep -qE '^\s*ii\s+cinnamon\b'; then
  log "SUCCESS: Cinnamon package is installed."
else
  log "WARNING: Cinnamon package not detected via dpkg -l. Check apt logs."
fi

log "Next steps:"
log "1) Reboot: sudo reboot"
log "2) On login screen, choose session: Cinnamon"
log "Done."

