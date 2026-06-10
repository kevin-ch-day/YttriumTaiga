#!/usr/bin/env bash
# YttriumTaiga core display helpers.

: "${YT_COLOR:=auto}"
: "${YT_THEME:=default}"

yt_is_tty() {
  [[ -t 1 ]]
}

yt_color_enabled() {
  case "$YT_COLOR" in
    1|true|yes) return 0 ;;
    0|false|no) return 1 ;;
    auto|*) yt_is_tty ;;
  esac
}

yt_color() {
  local code="${1:-0}"
  shift || true
  local text="$*"
  if yt_color_enabled; then
    printf '\033[%sm%s\033[0m' "$code" "$text"
  else
    printf '%s' "$text"
  fi
}

yt_section() {
  echo ""
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

yt_header() {
  local title="${1:-YttriumTaiga}"
  local subtitle="${2:-}"
  local ts
  ts="$(yt_ts 2>/dev/null || date)"

  local bar="################################################################################"
  echo ""
  case "$YT_THEME" in
    minimal)
      echo "$bar"
      printf "# %-76s #\n" "$title"
      [[ -n "$subtitle" ]] && printf "# %-76s #\n" "$subtitle"
      printf "# %-76s #\n" "Time: $ts"
      echo "$bar"
      ;;
    *)
      echo "$(yt_color 100 "$bar")"
      printf "$(yt_color 104 "# %-76s #\n")" "$title"
      [[ -n "$subtitle" ]] && printf "$(yt_color 104 "# %-76s #\n")" "$subtitle"
      printf "$(yt_color 100 "# %-76s #\n")" "Time: $ts"
      echo "$(yt_color 100 "$bar")"
      ;;
  esac
  echo ""
}

yt_kv() {
  local key="${1:-}"
  local val="${2:-}"
  printf '%-20s %s\n' "${key}:" "$val"
}

yt_ok() {
  echo "[ OK ] $*"
}

yt_fail() {
  echo "[FAIL] $*" >&2
}
