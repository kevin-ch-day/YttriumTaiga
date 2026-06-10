#!/usr/bin/env bash
# Taconite core display helpers.

: "${TACONITE_COLOR:=auto}"
: "${TACONITE_THEME:=default}"

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

taconite_color() {
  local code="${1:-0}"
  shift || true
  local text="$*"
  if taconite_color_enabled; then
    printf '\033[%sm%s\033[0m' "$code" "$text"
  else
    printf '%s' "$text"
  fi
}

taconite_section() {
  echo ""
  echo "============================================================"
  echo "$*"
  echo "============================================================"
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
      echo "$(taconite_color 100 "$bar")"
      printf "$(taconite_color 104 "# %-76s #\n")" "$title"
      [[ -n "$subtitle" ]] && printf "$(taconite_color 104 "# %-76s #\n")" "$subtitle"
      printf "$(taconite_color 100 "# %-76s #\n")" "Time: $ts"
      echo "$(taconite_color 100 "$bar")"
      ;;
  esac
  echo ""
}

taconite_kv() {
  local key="${1:-}"
  local val="${2:-}"
  printf '%-20s %s\n' "${key}:" "$val"
}

taconite_ok() {
  echo "[ OK ] $*"
}

taconite_fail() {
  echo "[FAIL] $*" >&2
}
