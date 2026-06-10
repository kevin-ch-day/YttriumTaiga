#!/usr/bin/env bash
# YttriumTaiga core validation helpers.

yt_require_cmds() {
  local missing=0 cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      yt_warn "Missing required command: $cmd"
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || return "$YT_E_MISSING_TOOL"
  return "$YT_E_OK"
}

yt_is_number() {
  local value="${1:-}"
  [[ "$value" =~ ^[0-9]+$ ]]
}

yt_validate_team() {
  local team="${1:-}"
  [[ "$team" =~ ^[0-9]{1,3}$ ]] || return 1
  [[ ! "$team" =~ ^0[0-9]+$ ]] || return 1
  (( team >= 1 && team <= 20 )) || return 1
  (( team != 19 )) || return 1
}

yt_platform_id() {
  if [[ -r /etc/os-release ]]; then
    awk -F= '$1=="ID" {gsub(/"/,"",$2); print $2}' /etc/os-release
  else
    echo "unknown"
  fi
}
