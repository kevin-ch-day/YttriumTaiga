#!/usr/bin/env bash
# lib/ccdc_menu.sh
set -euo pipefail

# ============================================================
# Purpose : Shared menu + prompt helpers for Phase 1 scripts
# Version : 0.3.0
#
# Design goals:
# - Library functions should NOT exit the caller.
# - Return non-zero on real errors; caller decides.
# - Safe under set -euo pipefail (avoid unhandled read failures).
# ============================================================

# Auto-enable color only if stdout is a TTY.
: "${CCDC_MENU_COLOR:=auto}"  # auto|0|1

# Optional shared theme/colors (config/theme)
_ccdc_menu__load_theme() {
  [[ "${CCDC_THEME_LOADED:-0}" == "1" ]] && return 0
  local lib_dir theme_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"
  theme_dir="${lib_dir}/../../config/theme"
  if [[ ! -f "${theme_dir}/ccdc_colors.sh" || ! -f "${theme_dir}/ccdc_theme.sh" ]]; then
    echo "ERROR: Missing required theme files in ${theme_dir} (ccdc_colors.sh / ccdc_theme.sh)" >&2
    return 1
  fi
  # shellcheck disable=SC1090
  source "${theme_dir}/ccdc_colors.sh"
  # shellcheck disable=SC1090
  source "${theme_dir}/ccdc_theme.sh"
  CCDC_THEME_LOADED=1
  return 0
}

# --- warn hook (integrates with ccdc_common.sh if present) ---
_ccdc_menu__warn() {
  local msg="$*"
  if declare -F ccdc__warn >/dev/null 2>&1; then
    ccdc__warn "$msg"
  else
    echo "WARN: $msg" >&2
  fi
}

# Route menu output to stderr so prompts and options stay together.
_ccdc_menu__out() {
  printf "%s\n" "$*" >&2
}

# Same as printf but to stderr (for formatted lines).
_ccdc_menu__outf() {
  # shellcheck disable=SC2059
  printf "$@" >&2
}

# ---------- TTY / color control ----------
ccdc_menu__is_interactive() {
  [[ -t 0 && -t 1 ]]
}

_ccdc_menu__is_tty() { [[ -t 1 ]]; }

_ccdc_menu__color_enabled() {
  case "${CCDC_MENU_COLOR}" in
    1|true|yes) return 0 ;;
    0|false|no) return 1 ;;
    auto) _ccdc_menu__is_tty ;;
    *) _ccdc_menu__is_tty ;;
  esac
}

_ccdc_menu__c() {
  # Usage: _ccdc_menu__c "32" "text"
  local code="$1"; shift
  local text="$*"
  if _ccdc_menu__color_enabled; then
    printf "\033[%sm%s\033[0m" "$code" "$text"
  else
    printf "%s" "$text"
  fi
}

# ---------- Formatting helpers ----------
ccdc_menu__header() {
  # Usage: ccdc_menu__header "Title" ["Subtitle"]
  local title="${1:-}"
  local subtitle="${2:-}"
  local ts
  if _ccdc_menu__load_theme; then
    ccdc_theme__header "$title" "$subtitle" >&2
    return 0
  fi

  ts="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"
  _ccdc_menu__out ""
  _ccdc_menu__out "################################################################################"
  _ccdc_menu__outf "# %-76s #\n" "$title"
  if [[ -n "$subtitle" ]]; then
    _ccdc_menu__outf "# %-76s #\n" "$subtitle"
  fi
  _ccdc_menu__outf "# %-76s #\n" "Time: $ts"
  _ccdc_menu__out "################################################################################"
  _ccdc_menu__out ""
}

ccdc_menu__divider() { _ccdc_menu__out "------------------------------------------------------------"; }

ccdc_menu__print_kv() {
  local k="${1:-}"
  local v="${2:-}"
  _ccdc_menu__outf "%-18s %s\n" "${k}:" "$v"
}

# ---------- Input helpers ----------
ccdc_menu__pause() {
  # Usage: ccdc_menu__pause ["prompt"]
  local prompt="${1:-Press ENTER to continue... }"
  local _tmp=""
  # Never let read kill the caller
  read -r -p "$prompt" _tmp || true
  return 0
}

ccdc_menu__ask() {
  # Free-text prompt with optional default.
  # Usage: val="$(ccdc_menu__ask "Enter team number" "21")"
  local prompt="${1:-Enter value}"
  local def="${2:-}"
  local ans=""

  if [[ -n "$def" ]]; then
    read -r -p "${prompt} [default: ${def}]: " ans || ans=""
    if [[ -z "$ans" ]]; then
      echo "$def"
      return 0
    fi
    echo "$ans"
    return 0
  fi

  read -r -p "${prompt}: " ans || ans=""
  echo "$ans"
  return 0
}

ccdc_menu__confirm() {
  # Usage: if ccdc_menu__confirm "Proceed?" "Y"; then ...; fi
  local prompt="${1:-Are you sure?}"
  local def="${2:-N}"   # default to N for safety
  def="${def^^}"

  local suffix
  [[ "$def" == "Y" ]] && suffix="[Y/n]" || suffix="[y/N]"

  local ans=""
  while true; do
    read -r -p "${prompt} ${suffix}: " ans || ans=""
    ans="${ans,,}"

    if [[ -z "$ans" ]]; then
      [[ "$def" == "Y" ]] && return 0 || return 1
    fi

    case "$ans" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *) echo "Please enter y or n." ;;
    esac
  done
}

ccdc_menu__choose() {
  # Prints options, reads choice, echoes chosen index (1-based).
  #
  # Usage:
  #   idx="$(ccdc_menu__choose "Select action" 1 "Run scan" "Show output" "Exit")"
  #
  # Behavior:
  # - Enter selects default (if default>0)
  # - 'q', 'quit', or '0' cancels -> echoes 0
  local title="${1:-Select}"; shift || true
  local default="${1:-0}"; shift || true
  local options=("$@")

  if (( ${#options[@]} == 0 )); then
    _ccdc_menu__warn "ccdc_menu__choose called with no options"
    echo "0"
    return 0
  fi

  _ccdc_menu__out ""
  _ccdc_menu__out "$title"
  _ccdc_menu__out "Options:"
  ccdc_menu__divider

  local i n
  for i in "${!options[@]}"; do
    n=$((i+1))
    if [[ "$n" -eq "$default" ]]; then
      _ccdc_menu__outf "  %d) %s %s\n" "$n" "${options[$i]}" "$(_ccdc_menu__c "36" "(default)")"
    else
      _ccdc_menu__outf "  %d) %s\n" "$n" "${options[$i]}"
    fi
  done
  _ccdc_menu__out "  0) Cancel / Back"
  if [[ "$default" -gt 0 ]]; then
    _ccdc_menu__out "Tip: Press Enter to choose the default option."
  fi
  _ccdc_menu__out "Type the number and press Enter."

  local choice=""
  while true; do
    local prompt="Choose [1-${#options[@]}]"
    if [[ "$default" -gt 0 ]]; then prompt+=" (Enter=${default})"; fi
    prompt+=": "

    read -r -p "$prompt" choice || choice=""
    choice="${choice,,}"

    if [[ -z "$choice" && "$default" -gt 0 ]]; then
      echo "$default"
      return 0
    fi

    case "$choice" in
      0|q|quit) echo "0"; return 0 ;;
    esac

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      echo "$choice"
      return 0
    fi
    echo "Invalid selection."
  done
}

ccdc_menu__choose_kv() {
  # Menu from label/value pairs; returns VALUE (or empty on cancel).
  #
  # Usage:
  #   val="$(ccdc_menu__choose_kv "Pick output" 1 "Services TXT" "./services.txt" "CSV" "./services.csv")"
  local title="${1:-Select}"; shift || true
  local default="${1:-0}"; shift || true

  if (( $# == 0 )); then
    _ccdc_menu__warn "ccdc_menu__choose_kv called with no pairs"
    echo ""
    return 0
  fi

  if (( $# % 2 != 0 )); then
    _ccdc_menu__warn "choose_kv expects label/value pairs (even number of args)"
    echo ""
    return 1
  fi

  local labels=()
  local values=()
  while (( $# > 0 )); do
    labels+=("$1"); shift
    values+=("$1"); shift
  done

  local idx
  idx="$(ccdc_menu__choose "$title" "$default" "${labels[@]}")"
  if [[ "$idx" == "0" ]]; then
    echo ""
    return 0
  fi

  echo "${values[$((idx-1))]}"
  return 0
}

ccdc_menu__pick_team() {
  # Interactive team selection helper.
  # Usage: TEAM="$(ccdc_menu__pick_team "$CURRENT_TEAM" "0")" || exit 0
  # allow_empty: "1" to allow unset team (returns empty string).
  local current="${1:-}"
  local allow_empty="${2:-0}"
  # If a team is already set and lock is requested, skip the menu.
  if [[ -n "$current" && "${CCDC_TEAM_LOCK:-0}" == "1" ]]; then
    echo "$current"
    return 0
  fi
  # Optional preset for non-interactive batch runs.
  if [[ -z "$current" && -n "${CCDC_TEAM_PRESET:-}" ]]; then
    echo "${CCDC_TEAM_PRESET}"
    return 0
  fi
  local _clean
  _clean() { printf "%s" "$1" | tr -d '[:space:]'; }
  local _print_team_list
  _print_team_list() {
    _ccdc_menu__out "Available teams (1-20; Team 19 blocked):"
    local i label
    for i in $(seq 1 20); do
      if declare -F ccdc__is_blocked_team >/dev/null 2>&1 && ccdc__is_blocked_team "$i"; then
        label="Team${i} [BLOCKED]"
      else
        label="Team${i}"
      fi
      _ccdc_menu__out "  - ${label}"
    done
  }

  while true; do
    current="$(_clean "$current")"
    ccdc_menu__header "Team Selection" "Choose the team number to target"
    if [[ -n "$current" ]]; then
      ccdc_menu__print_kv "Current team" "$current"
    else
      ccdc_menu__print_kv "Current team" "(none)"
    fi
    _ccdc_menu__out ""

    if [[ -n "$current" ]]; then
      local choice
      if [[ "$allow_empty" == "1" ]]; then
        choice="$(ccdc_menu__choose "Select action" 1 \
          "Use current team (${current})" \
          "Enter a new team number" \
          "Pick from list (1-20, Team19 blocked)" \
          "Continue without a team" \
          "Exit")"
      else
        choice="$(ccdc_menu__choose "Select action" 1 \
          "Use current team (${current})" \
          "Enter a new team number" \
          "Pick from list (1-20, Team19 blocked)" \
          "Exit")"
      fi
      case "$choice" in
        1) echo "$current"; return 0 ;;
        2)
          local ans
          ans="$(ccdc_menu__ask "Enter team number" "$current")"
          ans="$(_clean "$ans")"
          if declare -F ccdc__validate_team >/dev/null 2>&1; then
            ccdc__validate_team "$ans" || { _ccdc_menu__warn "Invalid team number: $ans"; continue; }
          else
            [[ "$ans" =~ ^[0-9]{1,3}$ ]] || { _ccdc_menu__warn "Invalid team number: $ans"; continue; }
          fi
          current="$ans"
          echo "$current"
          return 0
          ;;
        3)
          _print_team_list
          local pick
          pick="$(ccdc_menu__ask "Enter team number")"
          pick="$(_clean "$pick")"
          if declare -F ccdc__validate_team >/dev/null 2>&1; then
            ccdc__validate_team "$pick" || { _ccdc_menu__warn "Invalid team number: $pick"; continue; }
          else
            [[ "$pick" =~ ^[0-9]{1,3}$ ]] || { _ccdc_menu__warn "Invalid team number: $pick"; continue; }
          fi
          current="$pick"
          echo "$current"
          return 0
          ;;
        4)
          if [[ "$allow_empty" == "1" ]]; then
            echo ""
            return 0
          fi
          return 1
          ;;
        0|5) return 1 ;;
      esac
    else
      local choice2
      if [[ "$allow_empty" == "1" ]]; then
        choice2="$(ccdc_menu__choose "Select action" 1 \
          "Enter a team number" \
          "Pick from list (1-20, Team19 blocked)" \
          "Continue without a team" \
          "Exit")"
      else
        choice2="$(ccdc_menu__choose "Select action" 1 \
          "Enter a team number" \
          "Pick from list (1-20, Team19 blocked)" \
          "Exit")"
      fi
      case "$choice2" in
        1)
          local ans2
          ans2="$(ccdc_menu__ask "Enter team number")"
          ans2="$(_clean "$ans2")"
          if declare -F ccdc__validate_team >/dev/null 2>&1; then
            ccdc__validate_team "$ans2" || { _ccdc_menu__warn "Invalid team number: $ans2"; continue; }
          else
            [[ "$ans2" =~ ^[0-9]{1,3}$ ]] || { _ccdc_menu__warn "Invalid team number: $ans2"; continue; }
          fi
          current="$ans2"
          echo "$current"
          return 0
          ;;
        2)
          _print_team_list
          local pick2
          pick2="$(ccdc_menu__ask "Enter team number")"
          pick2="$(_clean "$pick2")"
          if declare -F ccdc__validate_team >/dev/null 2>&1; then
            ccdc__validate_team "$pick2" || { _ccdc_menu__warn "Invalid team number: $pick2"; continue; }
          else
            [[ "$pick2" =~ ^[0-9]{1,3}$ ]] || { _ccdc_menu__warn "Invalid team number: $pick2"; continue; }
          fi
          current="$pick2"
          echo "$current"
          return 0
          ;;
        3)
          if [[ "$allow_empty" == "1" ]]; then
            echo ""
            return 0
          fi
          return 1
          ;;
        0|4) return 1 ;;
      esac
    fi
  done
}

ccdc_menu__choose_multi() {
  # Multi-select: user enters "1,3,5" or "all" or "0" to cancel.
  # Returns a space-separated list of selected indices (1-based), or empty on cancel.
  #
  # Usage:
  #   picks="$(ccdc_menu__choose_multi "Select checks to run" "Ping" "DNS" "HTTP")"
  local title="${1:-Select items}"; shift || true
  local options=("$@")

  if (( ${#options[@]} == 0 )); then
    _ccdc_menu__warn "ccdc_menu__choose_multi called with no options"
    echo ""
    return 0
  fi

  echo ""
  echo "$title"
  ccdc_menu__divider
  local i
  for i in "${!options[@]}"; do
    printf "  %d) %s\n" "$((i+1))" "${options[$i]}"
  done
  echo "  all) Select all"
  echo "  0) Cancel / Back"

  local choice=""
  while true; do
    read -r -p "Choose (e.g. 1,3 or all): " choice || choice=""
    choice="${choice,,}"
    choice="$(echo "$choice" | tr -d ' ')" # remove spaces

    case "$choice" in
      0|q|quit) echo ""; return 0 ;;
      all)
        # return 1..N
        if command -v seq >/dev/null 2>&1; then
          seq 1 "${#options[@]}" | tr '\n' ' ' | sed 's/ *$//'
          return 0
        fi
        local j out=""
        for (( j=1; j<=${#options[@]}; j++ )); do
          out+="${j} "
        done
        echo "$out" | sed 's/ *$//'
        return 0
        ;;
    esac

    if [[ "$choice" =~ ^[0-9,]+$ ]]; then
      # validate each index
      local ok=1
      local out=""
      IFS=',' read -r -a parts <<< "$choice"
      for p in "${parts[@]}"; do
        [[ -n "$p" ]] || continue
        if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= ${#options[@]} )); then
          out+="${p} "
        else
          ok=0
          break
        fi
      done
      if [[ "$ok" -eq 1 && -n "$out" ]]; then
        echo "$out" | sed 's/ *$//'
        return 0
      fi
    fi

    echo "Invalid selection. Try 1,3 or all or 0."
  done
}
