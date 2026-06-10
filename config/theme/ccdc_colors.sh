#!/usr/bin/env bash
# config/theme/ccdc_colors.sh
set -euo pipefail

# ============================================================
# Shared Colors (Taconite brutalist palette)
# Version : 0.1.0
#
# Usage:
#   source ./config/theme/ccdc_colors.sh
#   ccdc_color__wrap "data" "OK"
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

CCDC_HEX_BLACK="#0A0A0A"
CCDC_HEX_CHARCOAL="#121212"
CCDC_HEX_CRIMSON="#990000"
CCDC_HEX_BLOOD="#CC0000"
CCDC_HEX_WHITE="#FFFFFF"
CCDC_HEX_GRAY="#444444"

ccdc_color__rgb_from_hex() {
  local hex="${1#\#}"
  printf '%d;%d;%d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

ccdc_color__role_hex() {
  case "${1:-data}" in
    bg|background) echo "$CCDC_HEX_BLACK" ;;
    panel|charcoal) echo "$CCDC_HEX_CHARCOAL" ;;
    accent|active|critical|fail|error) echo "$CCDC_HEX_CRIMSON" ;;
    payload) echo "$CCDC_HEX_BLOOD" ;;
    meta|metadata|inactive|divider|grid) echo "$CCDC_HEX_GRAY" ;;
    data|text|white|ok|*) echo "$CCDC_HEX_WHITE" ;;
  esac
}

ccdc_color__wrap() {
  # Usage: ccdc_color__wrap "accent|data|meta|payload" "text"
  local role="${1:-data}"; shift || true
  local text="$*"
  if ccdc_color__enabled; then
    case "$role" in
      31|91|100|101|104|active|accent|critical|fail|error) role="accent" ;;
      90|2|inactive|meta|metadata|divider|grid) role="meta" ;;
      32|33|34|35|36|37|97) role="data" ;;
    esac
    printf '\033[48;2;%sm\033[38;2;%sm%s\033[0m' \
      "$(ccdc_color__rgb_from_hex "$CCDC_HEX_BLACK")" \
      "$(ccdc_color__rgb_from_hex "$(ccdc_color__role_hex "$role")")" \
      "$text"
  else
    printf "%s" "$text"
  fi
}

# Common palette roles. These names intentionally avoid blue/pink/neon styling.
CCDC_C_RESET="0"
CCDC_C_BOLD="1"
CCDC_C_DIM="2"
CCDC_C_RED="accent"
CCDC_C_GRAY="meta"
CCDC_C_WHITE="data"
CCDC_C_PAYLOAD="payload"
CCDC_C_PANEL="panel"
