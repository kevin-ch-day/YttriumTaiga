#!/usr/bin/env bash
# lib/phase2_lib_remote.sh
set -euo pipefail

# ============================================================
# Phase 2 Remote Ops Library (SSH/SCP) — safe wrappers
# Version : 0.1.0
#
# Purpose:
# - Provide consistent SSH/SCP behavior for privilege expansion
# - Standardize timeouts, logging, and proof/loot output paths
# - Avoid exiting the caller; return non-zero on failure
#
# Integrations:
# - Uses Phase 2 meta defaults if sourced (timeouts, modes, output subdirs) :contentReference[oaicite:3]{index=3}
# - Uses Phase 2 runtime logging if available (phase2_log/phase2_warn) :contentReference[oaicite:4]{index=4}
# ============================================================

# -----------------------------
# Logging shims
# -----------------------------
_phase2_remote__warn() {
  local msg="$*"
  if declare -F phase2_warn >/dev/null 2>&1; then
    phase2_warn "$msg"
  else
    echo "WARN: $msg" >&2
  fi
}

_phase2_remote__log() {
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
: "${SSH_CONNECT_TIMEOUT_SEC_DEFAULT:=5}"
: "${PHASE2_MODE_DEFAULT:=standard}"
: "${REQUIRE_EXPLICIT_NOISY_FLAG_DEFAULT:=1}"

: "${PHASE2_SSH_CONNECT_TIMEOUT:=${SSH_CONNECT_TIMEOUT_SEC_DEFAULT}}"
: "${PHASE2_SSH_BATCH_MODE:=yes}"              # yes/no
: "${PHASE2_SSH_STRICT_HOST_KEY:=accept-new}"  # yes|no|accept-new
: "${PHASE2_SSH_PORT:=22}"
: "${PHASE2_REMOTE_MODE:=${PHASE2_MODE_DEFAULT}}"

# -----------------------------
# Output dirs (proof/loot)
# -----------------------------
phase2_remote__resolve_out_dir() {
  if declare -F phase2__resolve_out_dir >/dev/null 2>&1; then
    phase2__resolve_out_dir
    return 0
  fi

  # fallback infer
  local this_dir
  this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "$(cd "$this_dir/.." && pwd)/${PHASE_OUT_DIR:-output}"
}

phase2_remote__proof_dir() {
  local out_dir sub
  out_dir="$(phase2_remote__resolve_out_dir)" || return 1
  sub="${OUT_SUBDIR_PROOF:-proof}"
  echo "${out_dir}/${sub}"
}

phase2_remote__loot_dir() {
  local out_dir sub
  out_dir="$(phase2_remote__resolve_out_dir)" || return 1
  sub="${OUT_SUBDIR_LOOT:-loot}"
  echo "${out_dir}/${sub}"
}

phase2_remote__safe_slug() {
  # turn host/user into a filesystem-safe slug
  local s="${1:-}"
  s="${s// /_}"
  s="${s//:/_}"
  s="${s//\//_}"
  s="${s//@/_}"
  echo "$s" | tr -cd 'A-Za-z0-9._-'
}

phase2_remote__now_utc() {
  date -u '+%Y-%m-%dT%H%M%SZ' 2>/dev/null || date '+%Y-%m-%dT%H%M%S'
}

# -----------------------------
# Noisy gating
# -----------------------------
phase2_remote_guard_noisy() {
  # Enforce "no noisy actions unless explicitly allowed"
  # Usage: phase2_remote_guard_noisy "$mode" "$allow_noisy"
  local mode="${1:-${PHASE2_REMOTE_MODE}}"
  local allow_noisy="${2:-0}"

  if [[ "${REQUIRE_EXPLICIT_NOISY_FLAG_DEFAULT}" == "1" && "${mode}" == "noisy" && "${allow_noisy}" != "1" ]]; then
    _phase2_remote__warn "Blocked noisy mode action (set --noisy or allow_noisy=1)."
    return 1
  fi
  return 0
}

# -----------------------------
# SSH option builder
# -----------------------------
phase2_remote__ssh_base_args() {
  # Prints args suitable for: ssh $(phase2_remote__ssh_base_args) user@host
  # shellcheck disable=SC2034
  local args=()

  args+=("-o" "ConnectTimeout=${PHASE2_SSH_CONNECT_TIMEOUT}")
  args+=("-o" "BatchMode=${PHASE2_SSH_BATCH_MODE}")
  args+=("-o" "StrictHostKeyChecking=${PHASE2_SSH_STRICT_HOST_KEY}")
  args+=("-o" "UserKnownHostsFile=/dev/null") # reduce interactive prompts
  args+=("-p" "${PHASE2_SSH_PORT}")

  printf "%q " "${args[@]}"
}

# -----------------------------
# SSH primitives
# -----------------------------
phase2_remote_ssh_probe() {
  # Quick auth check (no command). Returns 0 if connection works.
  # Usage: phase2_remote_ssh_probe "user" "172.25.21.10" [port]
  local user="${1:-}"
  local host="${2:-}"
  local port="${3:-${PHASE2_SSH_PORT}}"

  [[ -n "$user" && -n "$host" ]] || return 1
  command -v ssh >/dev/null 2>&1 || { _phase2_remote__warn "ssh missing"; return 1; }

  PHASE2_SSH_PORT="$port"

  # shellcheck disable=SC2046
  ssh $(phase2_remote__ssh_base_args) "${user}@${host}" "true" </dev/null >/dev/null 2>&1
}

phase2_remote_ssh_cmd() {
  # Run remote command and capture stdout/stderr to a proof file.
  #
  # Usage:
  #   phase2_remote_ssh_cmd "user" "172.25.21.10" "id; uname -a" [--tag TAG] [--noisy]
  #
  # Returns: ssh exit code
  local user="${1:-}"
  local host="${2:-}"
  local cmd="${3:-}"
  shift 3 || true

  [[ -n "$user" && -n "$host" && -n "$cmd" ]] || return 1
  command -v ssh >/dev/null 2>&1 || { _phase2_remote__warn "ssh missing"; return 1; }

  local tag="cmd"
  local allow_noisy="0"
  while (( $# > 0 )); do
    case "$1" in
      --tag) shift; tag="${1:-cmd}" ;;
      --noisy) allow_noisy="1" ;;
    esac
    shift || true
  done

  phase2_remote_guard_noisy "${PHASE2_REMOTE_MODE}" "${allow_noisy}" || return 1

  local proof_dir
  proof_dir="$(phase2_remote__proof_dir)" || return 1
  mkdir -p "$proof_dir" 2>/dev/null || return 1

  local ts slug out_file
  ts="$(phase2_remote__now_utc)"
  slug="$(phase2_remote__safe_slug "${user}@${host}")"
  out_file="${proof_dir}/${slug}.${tag}.${ts}.txt"

  _phase2_remote__log "[*] SSH cmd -> ${user}@${host}  (tag=${tag})"
  _phase2_remote__log "[*] Proof  -> ${out_file}"

  {
    echo "=== Phase 2 Remote Command Proof ==="
    echo "Time (UTC): ${ts}"
    echo "Target: ${user}@${host}"
    echo "Tag: ${tag}"
    echo "Command:"
    echo "$cmd"
    echo "------------------------------------"
  } > "$out_file" 2>/dev/null || return 1

  local rc=0
  # shellcheck disable=SC2046
  ssh $(phase2_remote__ssh_base_args) "${user}@${host}" "$cmd" </dev/null >>"$out_file" 2>&1 || rc=$?

  echo "" >>"$out_file" 2>/dev/null || true
  echo "ExitCode: ${rc}" >>"$out_file" 2>/dev/null || true

  if [[ "$rc" -eq 0 ]]; then
    _phase2_remote__log "[*] SSH ok (rc=0)"
  else
    _phase2_remote__warn "SSH failed (rc=${rc})"
  fi

  # Echo proof path for callers
  echo "$out_file"
  return "$rc"
}

# -----------------------------
# SCP primitives
# -----------------------------
phase2_remote_scp_get() {
  # Copy remote file/dir to local loot path.
  #
  # Usage:
  #   phase2_remote_scp_get "user" "172.25.21.10" "/etc/passwd" ["local_name"] [--r]
  #
  # If local_name omitted, uses basename(remote_path).
  local user="${1:-}"
  local host="${2:-}"
  local remote_path="${3:-}"
  local local_name="${4:-}"
  shift 4 || true

  [[ -n "$user" && -n "$host" && -n "$remote_path" ]] || return 1
  command -v scp >/dev/null 2>&1 || { _phase2_remote__warn "scp missing"; return 1; }

  local recursive="0"
  while (( $# > 0 )); do
    case "$1" in
      --r|-r) recursive="1" ;;
    esac
    shift || true
  done

  local loot_dir
  loot_dir="$(phase2_remote__loot_dir)" || return 1
  mkdir -p "$loot_dir" 2>/dev/null || return 1

  if [[ -z "$local_name" ]]; then
    local_name="$(basename "$remote_path" 2>/dev/null || echo "loot.bin")"
  fi

  local ts slug dest
  ts="$(phase2_remote__now_utc)"
  slug="$(phase2_remote__safe_slug "${user}@${host}")"
  dest="${loot_dir}/${slug}.${ts}.${local_name}"

  _phase2_remote__log "[*] SCP get -> ${user}@${host}:${remote_path}"
  _phase2_remote__log "[*] Loot    -> ${dest}"

  local scp_args=()
  scp_args+=("-o" "ConnectTimeout=${PHASE2_SSH_CONNECT_TIMEOUT}")
  scp_args+=("-o" "BatchMode=${PHASE2_SSH_BATCH_MODE}")
  scp_args+=("-o" "StrictHostKeyChecking=${PHASE2_SSH_STRICT_HOST_KEY}")
  scp_args+=("-o" "UserKnownHostsFile=/dev/null")
  scp_args+=("-P" "${PHASE2_SSH_PORT}")
  if [[ "$recursive" == "1" ]]; then scp_args+=("-r"); fi

  local rc=0
  scp "${scp_args[@]}" "${user}@${host}:${remote_path}" "$dest" </dev/null >/dev/null 2>&1 || rc=$?

  if [[ "$rc" -eq 0 ]]; then
    _phase2_remote__log "[*] SCP ok"
    echo "$dest"
    return 0
  fi

  _phase2_remote__warn "SCP failed (rc=${rc})"
  return "$rc"
}

phase2_remote_scp_put() {
  # Copy local file to remote path.
  #
  # Usage:
  #   phase2_remote_scp_put "user" "172.25.21.10" "./file.bin" "/tmp/file.bin"
  local user="${1:-}"
  local host="${2:-}"
  local local_path="${3:-}"
  local remote_path="${4:-}"

  [[ -n "$user" && -n "$host" && -n "$local_path" && -n "$remote_path" ]] || return 1
  [[ -f "$local_path" ]] || { _phase2_remote__warn "Local file not found: $local_path"; return 1; }
  command -v scp >/dev/null 2>&1 || { _phase2_remote__warn "scp missing"; return 1; }

  local scp_args=()
  scp_args+=("-o" "ConnectTimeout=${PHASE2_SSH_CONNECT_TIMEOUT}")
  scp_args+=("-o" "BatchMode=${PHASE2_SSH_BATCH_MODE}")
  scp_args+=("-o" "StrictHostKeyChecking=${PHASE2_SSH_STRICT_HOST_KEY}")
  scp_args+=("-o" "UserKnownHostsFile=/dev/null")
  scp_args+=("-P" "${PHASE2_SSH_PORT}")

  _phase2_remote__log "[*] SCP put -> ${local_path}  =>  ${user}@${host}:${remote_path}"

  local rc=0
  scp "${scp_args[@]}" "$local_path" "${user}@${host}:${remote_path}" </dev/null >/dev/null 2>&1 || rc=$?

  if [[ "$rc" -eq 0 ]]; then
    _phase2_remote__log "[*] SCP ok"
    return 0
  fi

  _phase2_remote__warn "SCP failed (rc=${rc})"
  return "$rc"
}
