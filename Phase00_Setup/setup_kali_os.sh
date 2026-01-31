#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Filename: setup_kali_os.sh
# Purpose : Phase 0 - Red Team Environment Setup for Kali
# Version : 0.3.0
# Updated : 2026-01-30
#
# Run:
#   sudo ./setup_kali_os.sh
#
# Output (next to this script):
#   ./logs/setup_kali_os.log
#   ./output/setup_kali_os.summary.txt
#
# Design:
# - No CLI args (by design)
# - Log filename has NO timestamp (overwrites each run)
# - Installs common tooling and optional desktop/apps for competition readiness
# ============================================================

# ---- Require sudo/root ----
if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: Run with sudo:"
  echo "  sudo ./setup_kali_redteam.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
OUT_DIR="${SCRIPT_DIR}/output"
mkdir -p "$LOG_DIR" "$OUT_DIR"

LOG_FILE="${LOG_DIR}/setup_kali_os.log"
OUT_FILE="${OUT_DIR}/setup_kali_os.summary.txt"

: > "$LOG_FILE"
: > "$OUT_FILE"

# Ensure files stay writable for the invoking user when run via sudo
if [[ -n "${SUDO_USER:-}" ]]; then
  chown -R "${SUDO_USER}:${SUDO_USER}" "$LOG_DIR" "$OUT_DIR" 2>/dev/null || true
fi

# ---- Tunables (edit here; no CLI args) ----
INSTALL_DESKTOP="1"   # 1=yes, 0=no
INSTALL_VSCODE="1"    # 1=yes, 0=no
INSTALL_CHROME="1"    # 1=yes, 0=no
ENABLE_NEO4J="1"      # 1=yes, 0=no (only if neo4j installed)
MIN_FREE_GB="8"       # warn if less than this free on /

# ---- Output helpers ----
banner() {
  echo "################################################################################" | tee -a "$LOG_FILE"
  echo "#        KALI LINUX RED TEAM ENVIRONMENT SETUP (PHASE 0)                       #" | tee -a "$LOG_FILE"
  echo "################################################################################" | tee -a "$LOG_FILE"
}

section() {
  echo "" | tee -a "$LOG_FILE"
  echo "============================================================" | tee -a "$LOG_FILE"
  echo "$*" | tee -a "$LOG_FILE"
  echo "============================================================" | tee -a "$LOG_FILE"
}

log() { echo "$*" | tee -a "$LOG_FILE"; }
out() { echo "$*" >> "$OUT_FILE"; }

fail() {
  log "ERROR: $*"
  out "RESULT: FAIL - $*"
  exit 2
}

warn() {
  log "WARN: $*"
  out "WARN: $*"
}

have() { command -v "$1" >/dev/null 2>&1; }

is_kali() { grep -qi "kali" /etc/os-release 2>/dev/null; }

check_apt_locks() {
  local locks=(
    "/var/lib/dpkg/lock"
    "/var/lib/dpkg/lock-frontend"
    "/var/lib/apt/lists/lock"
    "/var/cache/apt/archives/lock"
  )
  for f in "${locks[@]}"; do
    if have fuser && fuser "$f" >/dev/null 2>&1; then
      fail "APT/DPKG lock in use: $f (another apt/dpkg process running)"
    fi
  done
}

check_disk_space() {
  local avail_kb
  avail_kb="$(df -Pk / | awk 'NR==2 {print $4}' 2>/dev/null || echo "")"
  if [[ -n "$avail_kb" ]]; then
    local avail_gb=$((avail_kb / 1024 / 1024))
    out "Disk free on /: ${avail_gb} GB"
    if [[ "$avail_gb" -lt "$MIN_FREE_GB" ]]; then
      warn "Low disk space on / (${avail_gb} GB free). Installs may fail."
    fi
  fi
}

apt_update_safe() {
  # Basic apt resilience for flaky networks
  mkdir -p /etc/apt/apt.conf.d
  cat >/etc/apt/apt.conf.d/99ccdc-phase0.conf <<'EOF'
Acquire::Retries "3";
Acquire::http::Timeout "10";
Acquire::https::Timeout "10";
Dpkg::Use-Pty "0";
EOF

  # Noninteractive mode
  export DEBIAN_FRONTEND=noninteractive
  apt-get update | tee -a "$LOG_FILE"
}

apt_install() {
  # Installs packages only if missing; still safe to run repeatedly.
  export DEBIAN_FRONTEND=noninteractive
  local pkgs=("$@")
  apt-get -y install "${pkgs[@]}" | tee -a "$LOG_FILE"
}

pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

install_vscode() {
  section "Install: Visual Studio Code"
  if pkg_installed code; then
    log "[*] VS Code already installed (package: code). Skipping."
    out "VS Code: already installed"
    return 0
  fi

  # Microsoft repo keyring + source list
  local keyring="/usr/share/keyrings/packages.microsoft.gpg"
  local listfile="/etc/apt/sources.list.d/vscode.list"

  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | tee "$keyring" >/dev/null

  chmod 0644 "$keyring"
  echo "deb [arch=amd64 signed-by=${keyring}] https://packages.microsoft.com/repos/vscode stable main" > "$listfile"

  apt_update_safe
  apt_install code

  out "VS Code: installed"
}

install_chrome() {
  section "Install: Google Chrome"
  if pkg_installed google-chrome-stable; then
    log "[*] Chrome already installed (google-chrome-stable). Skipping."
    out "Chrome: already installed"
    return 0
  fi

  local tmpdeb="/tmp/google-chrome-stable_current_amd64.deb"
  rm -f "$tmpdeb" || true

  curl -fL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "$tmpdeb"
  apt_install "$tmpdeb"
  rm -f "$tmpdeb" || true

  out "Chrome: installed"
}

maybe_install_desktop() {
  section "Install: Desktop Environment (optional)"
  if [[ "$INSTALL_DESKTOP" != "1" ]]; then
    log "[*] INSTALL_DESKTOP=0 (skipping)."
    out "Desktop: skipped"
    return 0
  fi

  # Cinnamon setup can be heavy; keep it explicit.
  apt_install kali-defaults kali-root-login desktop-base cinnamon
  out "Desktop (Cinnamon): installed"
}

setup_neo4j() {
  section "Configure: Neo4j (for BloodHound)"
  if [[ "$ENABLE_NEO4J" != "1" ]]; then
    log "[*] ENABLE_NEO4J=0 (skipping)."
    out "Neo4j: skipped"
    return 0
  fi
  if ! have systemctl; then
    warn "systemctl not available; cannot enable/start neo4j."
    out "Neo4j: systemctl missing"
    return 0
  fi
  if ! pkg_installed neo4j; then
    log "[*] neo4j not installed; skipping service enable/start."
    out "Neo4j: not installed"
    return 0
  fi

  systemctl enable neo4j.service >>"$LOG_FILE" 2>&1 || true
  systemctl start neo4j.service >>"$LOG_FILE" 2>&1 || true
  out "Neo4j: enabled+started (best-effort)"
}

rockyou_extract() {
  section "Wordlists: SecLists + RockYou"
  if pkg_installed seclists; then
    log "[*] seclists already installed."
  else
    apt_install seclists
  fi

  # RockYou is typically gzip'd on Kali.
  local gz="/usr/share/wordlists/rockyou.txt.gz"
  local txt="/usr/share/wordlists/rockyou.txt"

  if [[ -f "$txt" ]]; then
    log "[*] rockyou.txt already present. Skipping extract."
    out "RockYou: already extracted"
    return 0
  fi

  if [[ -f "$gz" ]]; then
    gzip -dk "$gz" >>"$LOG_FILE" 2>&1 || true
    if [[ -f "$txt" ]]; then
      out "RockYou: extracted"
    else
      warn "RockYou gzip exists but extraction did not produce rockyou.txt"
      out "RockYou: extract attempted"
    fi
  else
    warn "RockYou wordlist not found at expected path."
    out "RockYou: not found"
  fi
}

main() {
  banner
  section "Preflight"

  out "START: $(date)"
  out "Hostname: $(hostname)"
  out "Kernel: $(uname -r)"
  out "OS: $(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '\"' 2>/dev/null || true)"
  out "Script dir: $SCRIPT_DIR"
  out ""

  if ! is_kali; then
    fail "Not Kali (based on /etc/os-release). Refusing to run."
  fi

  check_apt_locks
  check_disk_space

  section "Step 1: Update package lists"
  apt_update_safe
  out "APT: updated"

  section "Step 2: Upgrade (safe default: full-upgrade)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y full-upgrade | tee -a "$LOG_FILE"
  out "APT: full-upgrade completed"

  section "Step 3: Baseline tools"
  # Keep baseline "competition essentials"
  apt_install \
    ca-certificates curl wget git jq unzip zip tar gzip \
    dnsutils net-tools iproute2 traceroute \
    tmux screen tree ripgrep htop \
    nmap openssl openssh-client \
    python3 python3-pip python3-venv pipx
  out "Baseline tools: installed"

  # Optional tools (commonly needed in CCDC red team environments)
  section "Step 4: Red team tools (packages)"
  apt_install metasploit-framework bloodhound neo4j python3-impacket crackmapexec wireshark
  out "Red team tool packages: installed"

  rockyou_extract

  if [[ "$INSTALL_VSCODE" == "1" ]]; then
    install_vscode
  else
    out "VS Code: skipped"
  fi

  if [[ "$INSTALL_CHROME" == "1" ]]; then
    install_chrome
  else
    out "Chrome: skipped"
  fi

  maybe_install_desktop
  setup_neo4j

  section "Cleanup"
  apt-get -y autoremove --purge | tee -a "$LOG_FILE" || true
  apt-get -y autoclean | tee -a "$LOG_FILE" || true

  # reboot hint
  local reboot_needed="no"
  [[ -f /var/run/reboot-required ]] && reboot_needed="yes"
  out ""
  out "Reboot required: $reboot_needed"
  out "END: $(date)"
  out "RESULT: OK"

  section "Done"
  log "[*] Log file : $LOG_FILE"
  log "[*] Summary  : $OUT_FILE"
  echo ""
  echo "[*] Done. See:"
  echo "    $LOG_FILE"
  echo "    $OUT_FILE"
}

main
