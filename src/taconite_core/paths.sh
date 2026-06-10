#!/usr/bin/env bash
# Taconite core path helpers.

taconite_core_dir() {
  (cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
}

taconite_repo_root() {
  local core_dir
  core_dir="$(taconite_core_dir)" || return 1
  (cd "${core_dir}/../.." && pwd)
}

taconite_intel_dir() {
  local root intel
  root="$(taconite_repo_root)" || return 1
  intel="${CCDC_INTEL_DIR:-data/intel}"
  if [[ "$intel" = /* ]]; then
    echo "$intel"
  else
    echo "${root}/${intel}"
  fi
}

taconite_team_dir() {
  local phase="${1:-}"
  local team="${2:-}"
  [[ -n "$phase" && -n "$team" ]] || return 1
  printf '%s/%s/team_%03d\n' "$(taconite_intel_dir)" "$phase" "$team"
}

taconite_require_repo_file() {
  local path="${1:-}"
  local root
  root="$(taconite_repo_root)" || return 1
  [[ -f "${root}/${path}" ]] || return 1
}
