#!/usr/bin/env bash
# lib/ccdc_colors.sh
set -euo pipefail

# ============================================================
# Phase 3 Colors (Kali-friendly, minimal)
# Version : 0.1.0
#
# Usage:
#   source ./lib/ccdc_colors.sh
#   ccdc_color__wrap "32" "OK"
#
# Control:
#   CCDC_COLOR=auto|0|1  (default: auto)
# ============================================================

: "${CCDC_COLOR:=auto}"

ccdc_color__is_tty() { [[ -t 1 ]]; }

ccdc_color__enabled() {
  case "${CCDC_COLOR}" in
    1|true|yes) return 0 ;;
    0|false|no) return 1 ;;
    auto) ccdc_color__is_tty ;;
    *) ccdc_color__is_tty ;;
  esac
}

ccdc_color__wrap() {
  # Usage: ccdc_color__wrap "31" "text"
  local code="${1:-0}"; shift || true
  local text="$*"
  if ccdc_color__enabled; then
    printf "\033[%sm%s\033[0m" "$code" "$text"
  else
    printf "%s" "$text"
  fi
}

# Common palette (Kali-friendly ANSI)
CCDC_C_RESET="0"
CCDC_C_BOLD="1"
CCDC_C_DIM="2"
CCDC_C_RED="31"
CCDC_C_GREEN="32"
CCDC_C_YELLOW="33"
CCDC_C_BLUE="34"
CCDC_C_MAGENTA="35"
CCDC_C_CYAN="36"
CCDC_C_GRAY="90"
