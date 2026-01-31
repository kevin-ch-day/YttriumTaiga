#!/usr/bin/env bash
# lib/phase2_lib_privesc.sh
set -euo pipefail

# ============================================================
# Phase 2 PrivEsc Triage Library (safe enum + proof scaffolding)
# Version : 0.1.0
#
# Purpose:
# - Collect *safe* local privilege escalation signals (Linux-focused)
# - Produce deterministic artifacts under output/enum/ and output/proof/
# - Provide a compact "next steps" summary to drive Phase 2 actions
#
# Notes:
# - No exploit automation. This is enumeration + reporting only.
# - Integrates with:
#   - phase2_lib_meta.sh for output subdirs and default tags :contentReference[oaicite:1]{index=1}
#   - phase2_lib_runtime.sh for logging if available :contentReference[oaicite:2]{index=2}
#   - phase2_lib_utils.sh for output dir resolution if available :contentReference[oaicite:3]{index=3}
# ============================================================

# -----------------------------
# Logging shims
# -----------------------------
_phase2_privesc__warn() {
  local msg="$*"
  if declare -F phase2_warn >/dev/null 2>&1; then
    phase2_warn "$msg"
  else
    echo "WARN: $msg" >&2
  fi
}

_phase2_privesc__log() {
  local msg="$*"
  if declare -F phase2_log >/dev/null 2>&1; then
    phase2_log "$msg"
  else
    echo "$msg"
  fi
}

# -----------------------------
# Meta-aware defaults
# -----------------------------
: "${OUT_SUBDIR_ENUM:=enum}"
: "${OUT_SUBDIR_PROOF:=proof}"
: "${PROOF_TAG_DEFAULT:=privexp}"   # from meta :contentReference[oaicite:4]{index=4}

# -----------------------------
# Output dirs
# -----------------------------
phase2_privesc__resolve_out_dir() {
  if declare -F phase2__resolve_out_dir >/dev/null 2>&1; then
    phase2__resolve_out_dir
    return 0
  fi
  local this_dir
  this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "$(cd "$this_dir/.." && pwd)/${PHASE_OUT_DIR:-output}"
}

phase2_privesc__enum_dir() {
  local out_dir
  out_dir="$(phase2_privesc__resolve_out_dir)" || return 1
  echo "${out_dir}/${OUT_SUBDIR_ENUM}"
}

phase2_privesc__proof_dir() {
  local out_dir
  out_dir="$(phase2_privesc__resolve_out_dir)" || return 1
  echo "${out_dir}/${OUT_SUBDIR_PROOF}"
}

phase2_privesc__safe_slug() {
  local s="${1:-}"
  s="${s// /_}"
  s="${s//:/_}"
  s="${s//\//_}"
  echo "$s" | tr -cd 'A-Za-z0-9._-'
}

phase2_privesc__now_utc() {
  date -u '+%Y-%m-%dT%H%M%SZ' 2>/dev/null || date '+%Y-%m-%dT%H%M%S'
}

# -----------------------------
# File writing helpers (prefer utils)
# -----------------------------
phase2_privesc__write_overwrite() {
  local path="${1:-}"
  local content="${2:-}"
  [[ -n "$path" ]] || return 1
  if declare -F phase2_write_file_overwrite >/dev/null 2>&1; then
    phase2_write_file_overwrite "$path" "$content"
  else
    printf "%s\n" "$content" > "$path" 2>/dev/null
  fi
}

phase2_privesc__append() {
  local path="${1:-}"
  local line="${2:-}"
  [[ -n "$path" ]] || return 1
  if declare -F phase2_append_line >/dev/null 2>&1; then
    phase2_append_line "$path" "$line"
  else
    printf "%s\n" "$line" >> "$path" 2>/dev/null
  fi
}

# -----------------------------
# Core: Linux local enum
# -----------------------------
phase2_privesc_linux_enum_local() {
  # Runs safe local checks and writes an enum report + next steps.
  #
  # Usage:
  #   phase2_privesc_linux_enum_local [--tag hostlabel]
  #
  # Outputs:
  #   output/enum/privesc_<tag>_<ts>.txt
  #   output/proof/next_steps_<tag>_<ts>.txt
  local tag="local"
  while (( $# > 0 )); do
    case "$1" in
      --tag) shift; tag="${1:-local}" ;;
    esac
    shift || true
  done
  tag="$(phase2_privesc__safe_slug "$tag")"
  local ts; ts="$(phase2_privesc__now_utc)"

  local enum_dir proof_dir
  enum_dir="$(phase2_privesc__enum_dir)" || return 1
  proof_dir="$(phase2_privesc__proof_dir)" || return 1
  mkdir -p "$enum_dir" "$proof_dir" 2>/dev/null || return 1

  local enum_file="${enum_dir}/privesc_${tag}_${ts}.txt"
  local next_file="${proof_dir}/next_steps_${tag}_${ts}.txt"

  _phase2_privesc__log "[*] PrivEsc enum (linux) tag=${tag}"
  _phase2_privesc__log "[*] Enum  -> ${enum_file}"
  _phase2_privesc__log "[*] Next  -> ${next_file}"

  {
    echo "=== Phase 2 PrivEsc Triage (Linux) ==="
    echo "Time (UTC):  ${ts}"
    echo "Tag:         ${tag}"
    echo "User:        $(whoami 2>/dev/null || echo unknown)"
    echo "UID/GID:     $(id 2>/dev/null || echo unknown)"
    echo "Hostname:    $(hostname 2>/dev/null || echo unknown)"
    echo "Kernel:      $(uname -a 2>/dev/null || echo unknown)"
    echo "Distro:      $( (cat /etc/os-release 2>/dev/null | tr '\n' ' ' ) || echo unknown)"
    echo "--------------------------------------"
  } > "$enum_file" 2>/dev/null || return 1

  # --- Quick checks (safe) ---
  phase2_privesc__append "$enum_file" ""
  phase2_privesc__append "$enum_file" "## Identity / Groups"
  (id 2>/dev/null || true) | while IFS= read -r l; do phase2_privesc__append "$enum_file" "$l"; done
  (groups 2>/dev/null || true) | while IFS= read -r l; do phase2_privesc__append "$enum_file" "$l"; done

  phase2_privesc__append "$enum_file" ""
  phase2_privesc__append "$enum_file" "## Sudo"
  if command -v sudo >/dev/null 2>&1; then
    (sudo -n -l 2>/dev/null || sudo -l 2>/dev/null || true) | while IFS= read -r l; do phase2_privesc__append "$enum_file" "$l"; done
  else
    phase2_privesc__append "$enum_file" "sudo: not present"
  fi

  phase2_privesc__append "$enum_file" ""
  phase2_privesc__append "$enum_file" "## Interesting environment"
  (umask 2>/dev/null || true) | while IFS= read -r l; do phase2_privesc__append "$enum_file" "$l"; done
  (echo "PATH=$PATH") | while IFS= read -r l; do phase2_privesc__append "$enum_file" "$l"; done

  phase2_privesc__append "$enum_file" ""
  phase2_privesc__append "$enum_file" "## Writable locations (quick)"
  for d in /etc /opt /srv /var/www /var/backups /var/log; do
    [[ -d "$d" ]] || continue
    if [[ -w "$d" ]]; then
      phase2_privesc__append "$enum_file" "writable: $d"
    fi
  done

  phase2_privesc__append "$enum_file" ""
  phase2_privesc__append "$enum_file" "## SUID/SGID binaries (top hits)"
  # Keep it light: first 200
  if command -v find >/dev/null 2>&1; then
    find / -xdev -perm -4000 -type f 2>/dev/null | head -n 200 | while IFS= read -r l; do phase2_privesc__append "$enum_file" "suid: $l"; done
    find / -xdev -perm -2000 -type f 2>/dev/null | head -n 200 | while IFS= read -r l; do phase2_privesc__append "$enum_file" "sgid: $l"; done
  else
    phase2_privesc__append "$enum_file" "find: not present"
  fi

  phase2_privesc__append "$enum_file" ""
  phase2_privesc__append "$enum_file" "## Capabilities (if getcap present)"
  if command -v getcap >/dev/null 2>&1; then
    (getcap -r / 2>/dev/null || true) | head -n 200 | while IFS= read -r l; do phase2_privesc__append "$enum_file" "$l"; done
  else
    phase2_privesc__append "$enum_file" "getcap: not present"
  fi

  phase2_privesc__append "$enum_file" ""
  phase2_privesc__append "$enum_file" "## Cron / systemd (read-only)"
  (ls -la /etc/cron* 2>/dev/null || true) | head -n 120 | while IFS= read -r l; do phase2_privesc__append "$enum_file" "$l"; done
  (systemctl list-timers --all 2>/dev/null || true) | head -n 120 | while IFS= read -r l; do phase2_privesc__append "$enum_file" "$l"; done

  phase2_privesc__append "$enum_file" ""
  phase2_privesc__append "$enum_file" "## Sensitive config readable checks (light)"
  for f in /etc/passwd /etc/shadow /etc/sudoers /etc/ssh/sshd_config /etc/mysql/my.cnf /var/www/html/config.php; do
    [[ -e "$f" ]] || continue
    if [[ -r "$f" ]]; then
      phase2_privesc__append "$enum_file" "readable: $f"
    else
      phase2_privesc__append "$enum_file" "not readable: $f"
    fi
  done

  # Build next steps file based on signals
  phase2_privesc_write_next_steps "$next_file" "$enum_file" "$tag" "$ts"
  echo "$enum_file"
  return 0
}

# -----------------------------
# Next steps generator
# -----------------------------
phase2_privesc_write_next_steps() {
  # Usage:
  #   phase2_privesc_write_next_steps <next_file> <enum_file> <tag> <ts>
  local next_file="${1:-}"
  local enum_file="${2:-}"
  local tag="${3:-local}"
  local ts="${4:-$(phase2_privesc__now_utc)}"
  [[ -n "$next_file" && -n "$enum_file" ]] || return 1

  local user; user="$(whoami 2>/dev/null || echo unknown)"

  {
    echo "=== Phase 2 PrivEsc Next Steps ==="
    echo "Time (UTC): ${ts}"
    echo "Tag:        ${tag}"
    echo "User:       ${user}"
    echo "Enum file:  ${enum_file}"
    echo ""
    echo "This is triage guidance based on safe signals; it does NOT run exploits."
    echo ""
    echo "Priority checks:"
    echo "  1) sudo rights (sudo -l) and NOPASSWD entries"
    echo "  2) writable service/unit files, cron jobs, or scripts run by root"
    echo "  3) interesting SUID/SGID and file capabilities (getcap)"
    echo "  4) readable secrets: config files, backups, keys"
    echo ""

    if command -v sudo >/dev/null 2>&1; then
      echo "Sudo:"
      if sudo -n -l >/dev/null 2>&1; then
        echo "  - sudo may be usable without password (sudo -n -l succeeded)"
      else
        echo "  - sudo present; review output in enum for NOPASSWD or allowed cmds"
      fi
      echo ""
    fi

    echo "Quick manual follow-ups (read-only):"
    echo "  - Check /etc/crontab, /etc/cron.*, and systemd timers for scripts you can edit"
    echo "  - Inspect /var/www, /opt, /srv for app configs or backups"
    echo "  - If you saw readable configs: extract creds and feed into Phase2 creds ledger"
    echo ""
    echo "Evidence:"
    echo "  - Save proof of any privilege boundary crossing: id; whoami; groups; sudo -l"
    echo "  - Keep outputs in output/proof/ with a clear tag"
    echo ""
  } > "$next_file" 2>/dev/null || return 1

  _phase2_privesc__log "[*] Wrote next steps: $next_file"
  return 0
}

# -----------------------------
# Quick-hit parser (optional helper)
# -----------------------------
phase2_privesc_linux_quick_hits() {
  # Reads an enum file and prints a short "hits" summary.
  # Usage: phase2_privesc_linux_quick_hits <enum_file>
  local enum_file="${1:-}"
  [[ -n "$enum_file" && -f "$enum_file" ]] || return 1

  command -v grep >/dev/null 2>&1 || { cat "$enum_file"; return 0; }

  echo "=== Quick Hits ==="
  grep -E 'sudo:|NOPASSWD|suid:|sgid:|readable:|writable:' "$enum_file" 2>/dev/null | head -n 80 || true
  return 0
}
