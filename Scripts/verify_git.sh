#!/usr/bin/env bash
# filename: verify_git.sh
set -euo pipefail

# ============================================================
# Verify (and optionally fix) global Git configuration (Kali/event-day)
# Version : 0.2.0
#
# Purpose:
# - Show current global git config (user.name/user.email + a few helpful defaults)
# - If missing, prompt to set (interactive) OR use env vars if provided
#
# Usage:
#   ./verify_git.sh
#
# Non-interactive (CI / scripted) usage:
#   GIT_USERNAME="kevin-ch-day" GIT_EMAIL="me@example.com" ./verify_git.sh.sh --fix
#
# Options:
#   --show   : only show (default behavior)
#   --fix    : set missing values (prompts if needed)
#
# Env vars (used with --fix):
#   GIT_USERNAME="..."
#   GIT_EMAIL="..."
#   GIT_DEFAULT_BRANCH="main"
# ============================================================

MODE="show"
if [[ "${1:-}" == "--fix" ]]; then
  MODE="fix"
elif [[ "${1:-}" == "--show" || -z "${1:-}" ]]; then
  MODE="show"
else
  echo "Usage: $0 [--show|--fix]"
  exit 1
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

section() {
  echo ""
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

get_git() {
  local key="$1"
  git config --global "$key" 2>/dev/null || true
}

set_git() {
  local key="$1"
  local val="$2"
  git config --global "$key" "$val"
}

show_global_git_config() {
  section "Global Git Configuration"

  local u e b ac pf
  u="$(get_git user.name)"
  e="$(get_git user.email)"
  b="$(get_git init.defaultBranch)"
  ac="$(get_git core.autocrlf)"
  pf="$(get_git fetch.prune)"

  printf "%-22s %s\n" "user.name:"          "${u:-<not set>}"
  printf "%-22s %s\n" "user.email:"         "${e:-<not set>}"
  printf "%-22s %s\n" "init.defaultBranch:" "${b:-<not set>}"
  printf "%-22s %s\n" "core.autocrlf:"      "${ac:-<not set>}"
  printf "%-22s %s\n" "fetch.prune:"        "${pf:-<not set>}"
}

fix_missing_config() {
  section "Fix Missing Git Configuration"

  if ! need_cmd git; then
    echo "ERROR: git is not installed."
    echo "Tip: run your setup script first: sudo ./setup_git.sh"
    exit 1
  fi

  local u e
  u="$(get_git user.name)"
  e="$(get_git user.email)"

  # user.name
  if [[ -z "$u" ]]; then
    if [[ -n "${GIT_USERNAME:-}" ]]; then
      set_git user.name "$GIT_USERNAME"
      echo "[*] Set user.name from env: $GIT_USERNAME"
    else
      if [[ -t 0 ]]; then
        read -r -p "Enter a global Git username: " u
        [[ -n "$u" ]] || { echo "ERROR: username cannot be empty"; exit 1; }
        set_git user.name "$u"
        echo "[*] Set user.name: $u"
      else
        echo "ERROR: user.name not set and no TTY to prompt. Set GIT_USERNAME and re-run --fix."
        exit 1
      fi
    fi
  else
    echo "[*] user.name already set: $u"
  fi

  # user.email
  if [[ -z "$e" ]]; then
    if [[ -n "${GIT_EMAIL:-}" ]]; then
      set_git user.email "$GIT_EMAIL"
      echo "[*] Set user.email from env: $GIT_EMAIL"
    else
      if [[ -t 0 ]]; then
        read -r -p "Enter a global Git email: " e
        [[ -n "$e" ]] || { echo "ERROR: email cannot be empty"; exit 1; }
        set_git user.email "$e"
        echo "[*] Set user.email: $e"
      else
        echo "ERROR: user.email not set and no TTY to prompt. Set GIT_EMAIL and re-run --fix."
        exit 1
      fi
    fi
  else
    echo "[*] user.email already set: $e"
  fi

  # Optional: default branch name (nice to standardize for the event)
  local db
  db="$(get_git init.defaultBranch)"
  if [[ -z "$db" ]]; then
    local want="${GIT_DEFAULT_BRANCH:-main}"
    set_git init.defaultBranch "$want"
    echo "[*] Set init.defaultBranch: $want"
  fi

  # Optional: safe-ish defaults
  if [[ -z "$(get_git fetch.prune)" ]]; then
    set_git fetch.prune true
    echo "[*] Set fetch.prune: true"
  fi

  if [[ -z "$(get_git core.autocrlf)" ]]; then
    set_git core.autocrlf input
    echo "[*] Set core.autocrlf: input"
  fi
}

main() {
  if [[ "$MODE" == "fix" ]]; then
    show_global_git_config
    fix_missing_config
    show_global_git_config
  else
    if ! need_cmd git; then
      echo "ERROR: git is not installed."
      echo "Tip: run your setup script first: sudo ./setup_git.sh"
      exit 1
    fi
    show_global_git_config
  fi
}

main "$@"
