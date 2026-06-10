#!/usr/bin/env bash
# Taconite core display helpers.

: "${TACONITE_COLOR:=auto}"
: "${TACONITE_THEME:=default}"

# Strict Taconite palette. Do not add blue, pink, retro neon, or scanline styles.
TACONITE_HEX_BLACK="#0A0A0A"
TACONITE_HEX_CHARCOAL="#121212"
TACONITE_HEX_CRIMSON="#990000"
TACONITE_HEX_BLOOD="#CC0000"
TACONITE_HEX_WHITE="#FFFFFF"
TACONITE_HEX_GRAY="#444444"

taconite_is_tty() {
  [[ -t 1 ]]
}

taconite_color_enabled() {
  case "$TACONITE_COLOR" in
    1|true|yes) return 0 ;;
    0|false|no) return 1 ;;
    auto|*) taconite_is_tty ;;
  esac
}

taconite_rgb_from_hex() {
  local hex="${1#\#}"
  printf '%d;%d;%d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

taconite_fg() {
  local hex="${1:-$TACONITE_HEX_WHITE}"
  printf '\033[38;2;%sm' "$(taconite_rgb_from_hex "$hex")"
}

taconite_bg() {
  local hex="${1:-$TACONITE_HEX_BLACK}"
  printf '\033[48;2;%sm' "$(taconite_rgb_from_hex "$hex")"
}

taconite_reset() {
  printf '\033[0m'
}

taconite_role_hex() {
  case "${1:-data}" in
    bg|background) echo "$TACONITE_HEX_BLACK" ;;
    panel|charcoal) echo "$TACONITE_HEX_CHARCOAL" ;;
    accent|active|critical|fail|error) echo "$TACONITE_HEX_CRIMSON" ;;
    payload) echo "$TACONITE_HEX_BLOOD" ;;
    meta|metadata|inactive|divider|grid) echo "$TACONITE_HEX_GRAY" ;;
    data|text|white|ok|*) echo "$TACONITE_HEX_WHITE" ;;
  esac
}

taconite_style() {
  local role="${1:-data}"
  shift || true
  local text="$*"
  if taconite_color_enabled; then
    printf '%s%s%s%s' "$(taconite_bg "$TACONITE_HEX_BLACK")" "$(taconite_fg "$(taconite_role_hex "$role")")" "$text" "$(taconite_reset)"
  else
    printf '%s' "$text"
  fi
}

taconite_color() {
  local code="${1:-data}"
  shift || true
  local text="$*"
  case "$code" in
    31|91|100|101|104|active|accent|critical|fail|error) taconite_style accent "$text" ;;
    90|2|inactive|meta|metadata|divider|grid) taconite_style meta "$text" ;;
    bg|background|panel|charcoal|payload|data|text|white|ok) taconite_style "$code" "$text" ;;
    *) taconite_style data "$text" ;;
  esac
}

taconite_section() {
  local line="################################################################################"
  echo ""
  echo "$(taconite_style meta "$line")"
  printf "%s\n" "$(taconite_style data "$*")"
  echo "$(taconite_style meta "$line")"
}

taconite_header() {
  local title="${1:-Taconite}"
  local subtitle="${2:-}"
  local ts
  ts="$(taconite_ts 2>/dev/null || date)"

  local bar="################################################################################"
  echo ""
  case "$TACONITE_THEME" in
    minimal)
      echo "$bar"
      printf "# %-76s #\n" "$title"
      [[ -n "$subtitle" ]] && printf "# %-76s #\n" "$subtitle"
      printf "# %-76s #\n" "Time: $ts"
      echo "$bar"
      ;;
    *)
      echo "$(taconite_style accent "$bar")"
      printf "%s\n" "$(taconite_style accent "$(printf "# %-76s #" "$title")")"
      [[ -n "$subtitle" ]] && printf "%s\n" "$(taconite_style data "$(printf "# %-76s #" "$subtitle")")"
      printf "%s\n" "$(taconite_style meta "$(printf "# %-76s #" "Time: $ts")")"
      echo "$(taconite_style accent "$bar")"
      ;;
  esac
  echo ""
}

taconite_kv() {
  local key="${1:-}"
  local val="${2:-}"
  printf '%s %s\n' "$(taconite_style meta "$(printf '%-20s' "${key}:")")" "$(taconite_style data "$val")"
}

taconite_ok() {
  printf '%s %s\n' "$(taconite_style meta "[ OK ]")" "$(taconite_style data "$*")"
}

taconite_fail() {
  printf '%s %s\n' "$(taconite_style accent "[FAIL]")" "$(taconite_style data "$*")" >&2
}
