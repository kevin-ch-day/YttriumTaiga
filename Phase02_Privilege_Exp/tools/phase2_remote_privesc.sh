#!/usr/bin/env bash
# phase2_remote_privesc.sh
set -euo pipefail

# ============================================================
# Phase 2 (Privilege Expansion) - Remote + PrivEsc Workflow
# Version : 0.1.0
#
# Purpose:
# - Test remote access (SSH probe)
# - Run proof commands remotely (id/uname/sudo -l, etc.)
# - Pull loot via SCP (read-only collection)
# - Generate a simple remote "privesc triage" proof pack
#
# Notes:
# - This script is Phase 2 only.
# - It does NOT run exploit automation.
# - It uses Phase 2 libs for logging, menu prompts, remote ops, and creds.
#
# Run:
#   chmod +x ./phase2_remote_privesc.sh
#   ./phase2_remote_privesc.sh
# ============================================================

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "${TOOL_DIR}/.." && pwd)"
LIB_DIR="${PHASE_DIR}/lib"

# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_meta.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_runtime.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_utils.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_menu.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_creds.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_remote.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/phase2_lib_privesc.sh"

# -----------------------------
# State (session)
# -----------------------------
PHASE2_RP_USER="${PHASE2_RP_USER:-}"
PHASE2_RP_HOST="${PHASE2_RP_HOST:-}"
PHASE2_RP_PORT="${PHASE2_RP_PORT:-${PHASE2_SSH_PORT:-22}}"
PHASE2_RP_TAG="${PHASE2_RP_TAG:-}"

phase2_rp__set_target() {
  phase2_section "Set Remote Target"

  local user host port tag

  user="$(phase2_menu__ask "SSH username" "${PHASE2_RP_USER}")"
  host="$(phase2_menu__ask "SSH host (ip or hostname)" "${PHASE2_RP_HOST}")"
  port="$(phase2_menu__ask "SSH port" "${PHASE2_RP_PORT}")"
  tag="$(phase2_menu__ask "Tag (for proof files)" "${PHASE2_RP_TAG:-${host}}")"

  [[ -n "$user" && -n "$host" ]] || { phase2_warn "user and host required"; return 1; }
  phase2_validate_port "$port" || { phase2_warn "invalid port: $port"; return 1; }

  PHASE2_RP_USER="$user"
  PHASE2_RP_HOST="$host"
  PHASE2_RP_PORT="$port"
  PHASE2_RP_TAG="$tag"

  # Push port into remote lib default for subsequent calls
  PHASE2_SSH_PORT="$PHASE2_RP_PORT"

  phase2_log_kv "User" "$PHASE2_RP_USER"
  phase2_log_kv "Host" "$PHASE2_RP_HOST"
  phase2_log_kv "Port" "$PHASE2_RP_PORT"
  phase2_log_kv "Tag"  "$PHASE2_RP_TAG"
  return 0
}

phase2_rp__require_target() {
  [[ -n "${PHASE2_RP_USER}" && -n "${PHASE2_RP_HOST}" ]] || {
    phase2_warn "No target set. Choose 'Set remote target' first."
    return 1
  }
  # Ensure port is applied
  PHASE2_SSH_PORT="${PHASE2_RP_PORT:-22}"
  return 0
}

phase2_rp__probe() {
  phase2_rp__require_target || return 1

  phase2_section "SSH Probe"
  phase2_log "[*] Probing ${PHASE2_RP_USER}@${PHASE2_RP_HOST}:${PHASE2_RP_PORT} ..."

  if phase2_remote_ssh_probe "$PHASE2_RP_USER" "$PHASE2_RP_HOST" "$PHASE2_RP_PORT"; then
    phase2_log "[*] Probe OK (auth + connectivity worked)"
    return 0
  fi

  phase2_warn "Probe failed. Check creds, network, port, or SSH availability."
  return 1
}

phase2_rp__run_proof_basic() {
  phase2_rp__require_target || return 1

  phase2_section "Remote Proof: Basic Identity"
  local cmd
  cmd=$'set -e\nwhoami\nid\nhostname\nuname -a\n( cat /etc/os-release 2>/dev/null | head -n 50 ) || true\n'

  local proof
  if proof="$(phase2_remote_ssh_cmd "$PHASE2_RP_USER" "$PHASE2_RP_HOST" "$cmd" --tag "proof_basic")" \
    && [[ -n "$proof" && -f "$proof" ]]; then
    phase2_log "[*] Saved proof: $proof"
    return 0
  fi
  phase2_warn "Failed to produce proof file."
  return 1
}

phase2_rp__run_proof_sudo() {
  phase2_rp__require_target || return 1

  phase2_section "Remote Proof: Sudo Rights"
  local cmd
  cmd=$'set -e\ncommand -v sudo >/dev/null 2>&1 || { echo "sudo not present"; exit 0; }\n(sudo -n -l 2>/dev/null || sudo -l 2>/dev/null || true)\n'

  local proof
  if proof="$(phase2_remote_ssh_cmd "$PHASE2_RP_USER" "$PHASE2_RP_HOST" "$cmd" --tag "proof_sudo")" \
    && [[ -n "$proof" && -f "$proof" ]]; then
    phase2_log "[*] Saved proof: $proof"
    return 0
  fi
  phase2_warn "Failed to produce sudo proof."
  return 1
}

phase2_rp__run_privesc_triage_remote() {
  phase2_rp__require_target || return 1

  phase2_section "Remote PrivEsc Triage (Safe)"
  phase2_log "[*] This produces proof outputs only (no exploits)."

  local cmd
  cmd=$'set -e\n\
echo "=== identity ==="\nwhoami\nid\n\
echo ""\n\
echo "=== sudo ==="\n\
if command -v sudo >/dev/null 2>&1; then (sudo -n -l 2>/dev/null || sudo -l 2>/dev/null || true); else echo "sudo not present"; fi\n\
echo ""\n\
echo "=== writable interesting dirs ==="\n\
for d in /etc /opt /srv /var/www /var/backups /var/log; do [ -d "$d" ] || continue; [ -w "$d" ] && echo "writable: $d" || true; done\n\
echo ""\n\
echo "=== suid/sgid (top hits) ==="\n\
if command -v find >/dev/null 2>&1; then find / -xdev -perm -4000 -type f 2>/dev/null | head -n 120; find / -xdev -perm -2000 -type f 2>/dev/null | head -n 120; else echo "find not present"; fi\n\
echo ""\n\
echo "=== capabilities (top hits) ==="\n\
if command -v getcap >/dev/null 2>&1; then getcap -r / 2>/dev/null | head -n 120; else echo "getcap not present"; fi\n\
echo ""\n\
echo "=== cron/systemd (light) ==="\n\
(ls -la /etc/cron* 2>/dev/null || true) | head -n 80\n\
(systemctl list-timers --all 2>/dev/null || true) | head -n 80\n\
echo ""\n\
echo "=== readable sensitive configs (light) ==="\n\
for f in /etc/passwd /etc/shadow /etc/sudoers /etc/ssh/sshd_config /etc/mysql/my.cnf /var/www/html/config.php; do [ -e "$f" ] || continue; [ -r "$f" ] && echo "readable: $f" || echo "not readable: $f"; done\n'

  local proof
  if proof="$(phase2_remote_ssh_cmd "$PHASE2_RP_USER" "$PHASE2_RP_HOST" "$cmd" --tag "privesc_triage_${PHASE2_RP_TAG:-remote}")" \
    && [[ -n "$proof" && -f "$proof" ]]; then
    phase2_log "[*] Saved triage proof: $proof"
    return 0
  fi
  phase2_warn "Failed to produce triage proof."
  return 1
}

phase2_rp__run_custom_cmd() {
  phase2_rp__require_target || return 1
  phase2_section "Remote Command (Custom)"

  local tag cmd
  tag="$(phase2_menu__ask "Tag for proof file" "custom")"
  cmd="$(phase2_menu__ask "Command to run on remote host" "id; whoami; uname -a")"
  [[ -n "$cmd" ]] || { phase2_warn "No command provided"; return 1; }

  local proof
  if proof="$(phase2_remote_ssh_cmd "$PHASE2_RP_USER" "$PHASE2_RP_HOST" "$cmd" --tag "$tag")" \
    && [[ -n "$proof" && -f "$proof" ]]; then
    phase2_log "[*] Saved proof: $proof"
    return 0
  fi
  return 1
}

phase2_rp__scp_get() {
  phase2_rp__require_target || return 1
  phase2_section "SCP Get (Loot Pull)"

  local remote_path local_name rec
  remote_path="$(phase2_menu__ask "Remote path to fetch" "/etc/passwd")"
  local_name="$(phase2_menu__ask "Local name (optional)" "")"
  rec="0"
  if phase2_menu__confirm "Recursive (-r)?" "N"; then
    rec="1"
  fi

  local out
  if [[ "$rec" == "1" ]]; then
    out="$(phase2_remote_scp_get "$PHASE2_RP_USER" "$PHASE2_RP_HOST" "$remote_path" "$local_name" --r 2>/dev/null || true)"
  else
    out="$(phase2_remote_scp_get "$PHASE2_RP_USER" "$PHASE2_RP_HOST" "$remote_path" "$local_name" 2>/dev/null || true)"
  fi

  if [[ -n "$out" && -e "$out" ]]; then
    phase2_log "[*] Loot saved: $out"
    return 0
  fi
  phase2_warn "SCP get failed."
  return 1
}

phase2_rp__suggest_creds_for_target() {
  phase2_section "Cred Ledger: Suggestions (by target token)"
  local token
  token="$(phase2_menu__ask "Target token (e.g., 172.25.21.10 or :22)" "${PHASE2_RP_HOST}")"
  [[ -n "$token" ]] || { phase2_warn "Token required"; return 1; }
  phase2_creds_init || true
  phase2_log "[*] Matching rows (CSV lines):"
  phase2_creds_best_for_target "$token" || {
    phase2_warn "No matches found (or ledger missing)."
    return 1
  }
  return 0
}

main_menu() {
  while true; do
    phase2_menu__header "${PHASE_NAME} v${PHASE_VERSION}" "Remote + PrivEsc"

    if [[ -n "${PHASE2_RP_USER}" && -n "${PHASE2_RP_HOST}" ]]; then
      phase2_menu__print_kv "Target" "${PHASE2_RP_USER}@${PHASE2_RP_HOST}:${PHASE2_RP_PORT}"
      [[ -n "${PHASE2_RP_TAG}" ]] && phase2_menu__print_kv "Tag" "${PHASE2_RP_TAG}"
    else
      phase2_menu__print_kv "Target" "(not set)"
    fi

    phase2_menu__divider
    local idx
    idx="$(
      phase2_menu__choose "Select an action" 1 \
        "Set remote target (user/host/port/tag)" \
        "SSH probe (connectivity/auth)" \
        "Remote proof: basic identity (whoami/id/uname/os-release)" \
        "Remote proof: sudo rights (sudo -l)" \
        "Remote PrivEsc triage (safe enum proof pack)" \
        "Run custom remote command (proof captured)" \
        "SCP get (pull loot)" \
        "Show cred ledger suggestions for this target" \
        "Back / Exit"
    )"

    case "$idx" in
      0|9) return 0 ;;
      1) phase2_rp__set_target || true; phase2_menu__pause ;;
      2) phase2_rp__probe || true; phase2_menu__pause ;;
      3) phase2_rp__run_proof_basic || true; phase2_menu__pause ;;
      4) phase2_rp__run_proof_sudo || true; phase2_menu__pause ;;
      5) phase2_rp__run_privesc_triage_remote || true; phase2_menu__pause ;;
      6) phase2_rp__run_custom_cmd || true; phase2_menu__pause ;;
      7) phase2_rp__scp_get || true; phase2_menu__pause ;;
      8) phase2_rp__suggest_creds_for_target || true; phase2_menu__pause ;;
      *) echo "Invalid selection."; phase2_menu__pause ;;
    esac
  done
}

main() {
  phase2_init_run "phase2_remote_privesc" || {
    echo "ERROR: failed to init Phase 2 runtime" >&2
    exit 1
  }

  # Ensure basic dirs exist early
  phase2_init_env || true
  phase2_creds_init || true

  main_menu
}

main "$@"
