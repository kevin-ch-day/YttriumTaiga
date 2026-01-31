#!/usr/bin/env bash
# lib/ccdc_theme.sh
set -euo pipefail

# ============================================================
# Phase 3 Theme (uses ccdc_colors.sh if sourced)
# Version : 0.1.0
#
# Usage:
#   source ./lib/ccdc_colors.sh
#   source ./lib/ccdc_theme.sh
#   ccdc_theme__header "Title" "Subtitle"
#
# Control:
#   CCDC_THEME=default|minimal (default: default)
# ============================================================

: "${CCDC_THEME:=default}"

ccdc_theme__c() {
  # Wrapper that works even if colors lib isn't loaded
  local code="$1"; shift || true
  local text="$*"
  if declare -F ccdc_color__wrap >/dev/null 2>&1; then
    ccdc_color__wrap "$code" "$text"
  else
    printf "%s" "$text"
  fi
}

ccdc_theme__divider() {
  local line="------------------------------------------------------------"
  case "${CCDC_THEME}" in
    minimal) echo "$line" ;;
    *) echo "$(ccdc_theme__c "90" "$line")" ;;
  esac
}

ccdc_theme__header() {
  local title="${1:-Phase 3}"
  local subtitle="${2:-Continuity}"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"

  local bar="################################################################################"
  case "${CCDC_THEME}" in
    minimal)
      echo ""
      echo "$bar"
      printf "# %-76s #\n" "$title"
      [[ -n "$subtitle" ]] && printf "# %-76s #\n" "$subtitle"
      printf "# %-76s #\n" "Time: $ts"
      echo "$bar"
      echo ""
      ;;
    *)
      echo ""
      echo "$(ccdc_theme__c "100" "$bar")"
      printf "$(ccdc_theme__c "104" "# %-76s #\n")" "$title"
      [[ -n "$subtitle" ]] && printf "$(ccdc_theme__c "104" "# %-76s #\n")" "$subtitle"
      printf "$(ccdc_theme__c "100" "# %-76s #\n")" "Time: $ts"
      echo "$(ccdc_theme__c "100" "$bar")"
      echo ""
      ;;
  esac
}

ccdc_theme__status_kv() {
  # Usage: ccdc_theme__status_kv "Status" "OK"
  local k="${1:-}"
  local v="${2:-}"
  local color="${3:-32}"
  printf "%-18s %s\n" "${k}:" "$(ccdc_theme__c "$color" "$v")"
}
