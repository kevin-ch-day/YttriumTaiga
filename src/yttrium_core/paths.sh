#!/usr/bin/env bash
# YttriumTaiga core path helpers.

yt_core_dir() {
  (cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
}

yt_repo_root() {
  local core_dir
  core_dir="$(yt_core_dir)" || return 1
  (cd "${core_dir}/../.." && pwd)
}

yt_intel_dir() {
  local root intel
  root="$(yt_repo_root)" || return 1
  intel="${CCDC_INTEL_DIR:-data/intel}"
  if [[ "$intel" = /* ]]; then
    echo "$intel"
  else
    echo "${root}/${intel}"
  fi
}

yt_team_dir() {
  local phase="${1:-}"
  local team="${2:-}"
  [[ -n "$phase" && -n "$team" ]] || return 1
  printf '%s/%s/team_%03d\n' "$(yt_intel_dir)" "$phase" "$team"
}

yt_require_repo_file() {
  local path="${1:-}"
  local root
  root="$(yt_repo_root)" || return 1
  [[ -f "${root}/${path}" ]] || return 1
}
