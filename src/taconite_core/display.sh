#!/usr/bin/env bash
# Taconite core display helpers.

: "${TACONITE_COLOR:=auto}"
: "${TACONITE_THEME:=default}"
: "${TACONITE_FRAME_WIDTH:=80}"

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

taconite_repeat() {
  local char="${1:-#}"
  local count="${2:-$TACONITE_FRAME_WIDTH}"
  local out=""
  while (( ${#out} < count )); do
    out+="$char"
  done
  printf '%s' "${out:0:count}"
}

taconite_rule() {
  local role="${1:-meta}"
  local char="${2:-#}"
  local width="${3:-$TACONITE_FRAME_WIDTH}"
  taconite_style "$role" "$(taconite_repeat "$char" "$width")"
}

taconite_frame_line() {
  local role="${1:-data}"
  local text="${2:-}"
  local width="${3:-$TACONITE_FRAME_WIDTH}"
  local inner_width=$((width - 4))
  (( inner_width > 0 )) || inner_width=76
  taconite_style "$role" "$(printf '# %-*.*s #' "$inner_width" "$inner_width" "$text")"
}

taconite_frame() {
  local title="${1:-Taconite}"
  local subtitle="${2:-}"
  local state="${3:-active}"
  local ts
  ts="$(taconite_ts 2>/dev/null || date)"

  echo ""
  echo "$(taconite_rule "$state" "#")"
  echo "$(taconite_frame_line "$state" "$title")"
  [[ -n "$subtitle" ]] && echo "$(taconite_frame_line data "$subtitle")"
  echo "$(taconite_frame_line meta "Time: $ts")"
  echo "$(taconite_rule "$state" "#")"
  echo ""
}

taconite_section() {
  local title="$*"
  echo ""
  echo "$(taconite_rule meta "#")"
  printf "%s\n" "$(taconite_frame_line data "$title")"
  echo "$(taconite_rule meta "#")"
}

taconite_header() {
  local title="${1:-Taconite}"
  local subtitle="${2:-}"
  local ts
  ts="$(taconite_ts 2>/dev/null || date)"

  case "$TACONITE_THEME" in
    minimal)
      local bar
      bar="$(taconite_repeat "#")"
      echo ""
      echo "$bar"
      printf "# %-76s #\n" "$title"
      [[ -n "$subtitle" ]] && printf "# %-76s #\n" "$subtitle"
      printf "# %-76s #\n" "Time: $ts"
      echo "$bar"
      echo ""
      ;;
    *)
      taconite_frame "$title" "$subtitle" "accent"
      ;;
  esac
}

taconite_kv() {
  local key="${1:-}"
  local val="${2:-}"
  printf '%s %s\n' "$(taconite_style meta "$(printf '%-20s' "${key}:")")" "$(taconite_style data "$val")"
}

taconite_ok() {
  taconite_status ok "$*"
}

taconite_warn_line() {
  taconite_status warn "$*"
}

taconite_fail() {
  taconite_status fail "$*" >&2
}

taconite_status() {
  local state="${1:-info}"
  shift || true
  local label role
  case "$state" in
    ok|pass|ready) label="[PASS]"; role="data" ;;
    warn|warning) label="[WARN]"; role="meta" ;;
    fail|error|critical) label="[FAIL]"; role="accent" ;;
    payload|exec) label="[EXEC]"; role="payload" ;;
    info|*) label="[DATA]"; role="meta" ;;
  esac
  printf '%s %s\n' "$(taconite_style "$role" "$label")" "$(taconite_style data "$*")"
}
