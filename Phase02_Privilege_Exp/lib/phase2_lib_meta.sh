#!/usr/bin/env bash
# =============================================================================
# File:    phase2_lib_meta.sh
# Purpose: Phase 2 (Privilege Expansion) -- phase-local metadata + defaults
# Notes:   This file is ONLY about Phase 2. No cross-phase assumptions.
# =============================================================================
# shellcheck shell=bash

# -----------------------------
# Identity
# -----------------------------
PHASE_ID="phase2"
PHASE_NAME="Phase 2 (Privilege Expansion)"
PHASE_VERSION="0.1.0"

# -----------------------------
# Phase-local folders (relative to Phase 2 root)
# -----------------------------
PHASE_LOG_DIR="logs"
PHASE_OUT_DIR="output"
PHASE_TMP_DIR="tmp"

# -----------------------------
# Logging defaults
# (No timestamped filenames; keep stable names for event-day use)
# -----------------------------
LOG_FILE_DEFAULT="phase2.log"
LOG_MODE_DEFAULT="append"   # append|overwrite
VERBOSE_DEFAULT="1"         # 1=more console output, 0=quiet

# Optional console suppression hook (runtime can map this to PHASE2_QUIET)
QUIET_DEFAULT="0"           # 1=quiet, 0=normal

# -----------------------------
# Safety defaults (Phase 2 can get risky fast)
# -----------------------------
DRY_RUN_DEFAULT="0"                 # 1=default dry-run
REQUIRE_ROOT_DEFAULT="0"            # 1=enforce sudo
CONFIRM_DESTRUCTIVE_DEFAULT="1"     # 1=require typed confirm for risky actions

# Optional: require an explicit flag before running "noisy" actions
REQUIRE_EXPLICIT_NOISY_FLAG_DEFAULT="1"  # 1=block loud actions unless --noisy

# -----------------------------
# Tool requirements (Phase 2 focus)
# Keep REQUIRED minimal. OPTIONAL can be installed as-needed.
# -----------------------------
REQUIRED_TOOLS=(bash grep sed awk find)
OPTIONAL_TOOLS=(
  curl wget jq
  ssh scp
  nmap
  python3
  openssl
  sudo
)

# -----------------------------
# Output naming conventions (Phase 2 local)
# These help keep artifacts predictable for writeups.
# -----------------------------
OUT_SUBDIR_ENUM="enum"
OUT_SUBDIR_LOOT="loot"
OUT_SUBDIR_PROOF="proof"
OUT_SUBDIR_NOTES="notes"

# -----------------------------
# Phase 2 knobs (defaults)
# Tune these per environment during the event.
# -----------------------------

# Connection / timeout behavior
SSH_CONNECT_TIMEOUT_SEC_DEFAULT="5"
HTTP_TIMEOUT_SEC_DEFAULT="5"

# Enumeration "depth" (light by default)
ENUM_MAX_TARGETS_DEFAULT="50"    # safety cap for loops over hosts
ENUM_MAX_PORTS_DEFAULT="200"     # when doing targeted re-scans

# Password spraying / auth attempts (keep conservative)
AUTH_MAX_TRIES_PER_HOST_DEFAULT="3"
AUTH_MAX_USERS_DEFAULT="25"

# Local proof file naming
PROOF_TAG_DEFAULT="privexp"

# -----------------------------
# Phase 2 allowed modes
# Helps scripts validate arguments consistently.
# -----------------------------
PHASE2_ALLOWED_MODES=("safe" "standard" "noisy")

# Default mode used when scripts support --mode
PHASE2_MODE_DEFAULT="standard"
