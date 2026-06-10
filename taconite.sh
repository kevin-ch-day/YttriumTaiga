#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/src/taconite_core/kernel.sh"
taconite_enable_error_trap "$(basename "$0")"

usage() {
  cat <<'EOF'
Usage: ./taconite.sh <command> [args]

Commands:
  menu                         Interactive Taconite launcher
  phase <0-6|name> [args...]   Launch a phase operator
  validate [args...]           Run Scripts/ccdc_validate.sh
  smoke                        Run Scripts/ccdc_smoke_test.sh
  brief --team <N> [args...]   Run Scripts/ccdc_team_brief.py
  version                      Print version banner
  help                         Show this help

Examples:
  ./taconite.sh menu
  ./taconite.sh phase 1
  ./taconite.sh phase 2 --team 1 --preset fast
  ./taconite.sh validate --with-smoke
  ./taconite.sh brief --team 1
EOF
}

run_script() {
  local script="${1:-}"
  shift || true
  [[ -n "$script" ]] || taconite_die "$TACONITE_E_USAGE" "missing script"
  [[ -x "${ROOT_DIR}/${script}" ]] || taconite_die "$TACONITE_E_IO" "script not executable: $script"
  exec "${ROOT_DIR}/${script}" "$@"
}

menu() {
  while true; do
    taconite_frame "Taconite" "Red Team Operating Core" "accent"
    taconite_print_phase_list
    echo ""
    taconite_kv "v" "Validate"
    taconite_kv "s" "Smoke tests"
    taconite_kv "b" "Team brief"
    taconite_kv "q" "Quit"
    echo ""
    read -r -p "TACONITE> " choice || choice=""
    case "$choice" in
      0|00|setup) taconite_run_phase 0 ;;
      1|01|recon) taconite_run_phase 1 ;;
      2|02|privilege|privexp) taconite_run_phase 2 ;;
      3|03|persistence|continuity) taconite_run_phase 3 ;;
      4|04|disruption) taconite_run_phase 4 ;;
      5|05|kill) taconite_run_phase 5 ;;
      6|06|dayend|cleanup) taconite_run_phase 6 ;;
      v|V|validate) run_script "Scripts/ccdc_validate.sh" ;;
      s|S|smoke) run_script "Scripts/ccdc_smoke_test.sh" ;;
      b|B|brief)
        local team
        read -r -p "Team number: " team || team=""
        taconite_validate_team "$team" || {
          taconite_fail "Invalid or blocked team: $team"
          continue
        }
        run_script "Scripts/ccdc_team_brief.py" --team "$team"
        ;;
      q|Q|quit|exit) exit 0 ;;
      "") taconite_warn "No selection made." ;;
      *) taconite_fail "Unknown selection: $choice" ;;
    esac
  done
}

cmd="${1:-menu}"
shift || true

case "$cmd" in
  menu) menu ;;
  phase) taconite_run_phase "${1:-}" "${@:2}" ;;
  validate) run_script "Scripts/ccdc_validate.sh" "$@" ;;
  smoke) run_script "Scripts/ccdc_smoke_test.sh" "$@" ;;
  brief) run_script "Scripts/ccdc_team_brief.py" "$@" ;;
  version) run_script "config/version_info.sh" ;;
  help|-h|--help) usage ;;
  *) usage >&2; taconite_die "$TACONITE_E_USAGE" "Unknown command: $cmd" ;;
esac
