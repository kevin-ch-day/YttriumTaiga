#!/usr/bin/env bash
# filename: disk_usage_checker.sh
set -euo pipefail

# ============================================================
# Disk Usage Checker (Event-Day Safe)
# Version : 0.3.0
#
# Goals:
# - Fast, reliable disk + inode usage overview
# - Optional "heavy" scans for top dirs/files (disabled by default)
# - Never leaves background spinner running
# - Works even if optional commands are missing (iostat/column/fdisk)
#
# Usage:
#   ./disk_usage_checker.sh
#
# Options:
#   --heavy          # enable heavier scans (top dirs/files)
#   --path <PATH>    # base path for heavy scans (default: /)
#   --top <N>        # number of items for top lists (default: 10)
#   --no-color       # disable ANSI colors
#
# Notes:
# - Heavy scans can be slow on competition images; keep off unless needed.
# ============================================================

HEAVY=0
BASE_PATH="/"
TOP_N=10
USE_COLOR=1

while (( $# > 0 )); do
  case "$1" in
    --heavy) HEAVY=1 ;;
    --path) shift; BASE_PATH="${1:-/}" ;;
    --top) shift; TOP_N="${1:-10}" ;;
    --no-color) USE_COLOR=0 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--heavy] [--path PATH] [--top N] [--no-color]
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift || true
done

# -----------------------------
# Color helpers
# -----------------------------
c() {
  local code="$1"; shift
  local text="$*"
  if [[ "$USE_COLOR" == "1" && -t 1 ]]; then
    printf "\033[%sm%s\033[0m" "$code" "$text"
  else
    printf "%s" "$text"
  fi
}

section() {
  echo ""
  echo "$(c "1;44" "============================================================")"
  echo "$(c "1;42" " $* ")"
  echo "$(c "1;44" "============================================================")"
  echo ""
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Prefer column if present
maybe_column() {
  if need_cmd column; then
    column -t
  else
    cat
  fi
}

# -----------------------------
# Spinner (safe cleanup)
# -----------------------------
SPINNER_PID=""
spinner_start() {
  local msg="$1"
  if [[ ! -t 1 ]]; then
    return 0
  fi
  (
    while true; do
      echo -ne "$(c "1;96" "$msg")\r"
      sleep 1
    done
  ) &
  SPINNER_PID="$!"
}

spinner_stop() {
  if [[ -n "${SPINNER_PID}" ]]; then
    kill "${SPINNER_PID}" >/dev/null 2>&1 || true
    wait "${SPINNER_PID}" >/dev/null 2>&1 || true
    SPINNER_PID=""
    if [[ -t 1 ]]; then
      echo -ne " \r"
    fi
  fi
}

cleanup() { spinner_stop; }
trap cleanup EXIT INT TERM

# -----------------------------
# Header
# -----------------------------
echo "$(c "1;100" "################################################################################")"
echo "$(c "1;104" "                      DISK USAGE CHECKER (SAFE)                               ")"
echo "$(c "1;100" "################################################################################")"
echo ""

# -----------------------------
# Step 1: Overall disk usage
# -----------------------------
section "1) Overall Disk Usage (df -h)"
if need_cmd df; then
  df -h | maybe_column || echo "$(c "1;91" "Failed to fetch disk usage info.")"
else
  echo "$(c "1;91" "df not found.")"
fi

# -----------------------------
# Step 2: Disk usage by mount + fstype
# -----------------------------
section "2) Disk Usage by Mount Point (df -hT)"
if need_cmd df; then
  df -hT | maybe_column || echo "$(c "1;91" "Failed to fetch mount usage.")"
else
  echo "$(c "1;91" "df not found.")"
fi

# -----------------------------
# Step 3: Inode usage
# -----------------------------
section "3) Inode Usage (df -i)"
if need_cmd df; then
  df -i | maybe_column || echo "$(c "1;91" "Failed to fetch inode usage.")"
else
  echo "$(c "1;91" "df not found.")"
fi

# -----------------------------
# Step 4: Filesystem info (lsblk)
# -----------------------------
section "4) Filesystems (lsblk)"
if need_cmd lsblk; then
  lsblk -o NAME,SIZE,FSTYPE,FSVER,LABEL,UUID,FSAVAIL,FSUSE%,MOUNTPOINTS 2>/dev/null | maybe_column \
    || echo "$(c "1;91" "Failed to fetch lsblk info.")"
else
  echo "$(c "1;93" "lsblk not found; skipping.")"
fi

# -----------------------------
# Step 5: Disk partitions (fdisk) - optional
# -----------------------------
section "5) Disk Partitions (fdisk) [optional]"
if need_cmd fdisk; then
  fdisk -l 2>/dev/null | grep -E '^Disk /' | maybe_column || echo "$(c "1;93" "No fdisk output / permissions restricted.")"
else
  echo "$(c "1;93" "fdisk not found; skipping.")"
fi

# -----------------------------
# Step 6: Disk I/O stats (iostat) - optional
# -----------------------------
section "6) Disk I/O Statistics (iostat) [optional]"
if need_cmd iostat; then
  iostat -dx 1 3 | maybe_column || echo "$(c "1;91" "Failed to fetch iostat stats.")"
else
  echo "$(c "1;93" "iostat not found (install sysstat if needed). Skipping.")"
fi

# -----------------------------
# Step 7: Usage summary + warnings
# -----------------------------
section "7) Usage Summary + Warnings"
if need_cmd df && need_cmd awk; then
  df -h | awk 'NR==1{print;next} {printf "%-20s %-8s %-8s %-8s %-6s %s\n",$1,$2,$3,$4,$5,$6}' | maybe_column

  echo ""
  df -h | awk '
    NR>1 {
      # strip %
      gsub(/%/,"",$5);
      if ($5+0 >= 90) printf "\033[1;91mCRITICAL:\033[0m %-20s %3s%% used on %s\n",$1,$5,$6;
      else if ($5+0 >= 80) printf "\033[1;93mWARN:\033[0m     %-20s %3s%% used on %s\n",$1,$5,$6;
      else printf "\033[1;92mOK:\033[0m       %-20s %3s%% used on %s\n",$1,$5,$6;
    }' || true
else
  echo "$(c "1;91" "df/awk missing; cannot compute warnings.")"
fi

# -----------------------------
# Step 8: Heavy scans (optional)
# -----------------------------
if [[ "$HEAVY" == "1" ]]; then
  section "8) Heavy: Largest Directories (du) under ${BASE_PATH} (top ${TOP_N})"
  if need_cmd du && need_cmd sort && need_cmd head; then
    spinner_start "Analyzing directories... (heavy)"
    # limit to one filesystem and shallow depth; still can be slow on /
    du -xh "${BASE_PATH}" --max-depth=1 2>/dev/null | sort -rh | head -n "${TOP_N}" | maybe_column || true
    spinner_stop
  else
    echo "$(c "1;93" "du/sort/head missing; skipping.")"
  fi

  section "9) Heavy: Largest Files (find + du) under ${BASE_PATH} (top ${TOP_N})"
  if need_cmd find && need_cmd du && need_cmd sort && need_cmd head; then
    spinner_start "Analyzing files... (heavy)"
    # safer approach: size via find -printf if GNU find supports it
    if find "${BASE_PATH}" -xdev -type f -printf '%s %p\n' >/dev/null 2>&1; then
      find "${BASE_PATH}" -xdev -type f -printf '%s %p\n' 2>/dev/null \
        | sort -nr | head -n "${TOP_N}" \
        | awk '{sz=$1; $1=""; sub(/^ /,""); printf "%.2fMB  %s\n", sz/1024/1024, $0 }' \
        | maybe_column || true
    else
      # fallback: slower du
      find "${BASE_PATH}" -xdev -type f -exec du -h {} + 2>/dev/null \
        | sort -rh | head -n "${TOP_N}" | maybe_column || true
    fi
    spinner_stop
  else
    echo "$(c "1;93" "find/du/sort/head missing; skipping.")"
  fi
else
  section "8) Heavy scans disabled"
  echo "Run with --heavy to include top directories/files scans."
  echo "Example: $0 --heavy --path / --top 10"
fi

# -----------------------------
# Final
# -----------------------------
echo ""
echo "$(c "1;100" "################################################################################")"
echo "$(c "1;102" " Disk Usage Check Complete ")"
echo "$(c "1;100" "################################################################################")"
