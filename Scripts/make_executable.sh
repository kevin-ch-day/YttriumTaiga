#!/usr/bin/env bash
# filename: make_executable.sh
set -euo pipefail

# ============================================================
# Make Shell Scripts Executable (Event-Day Safe)
# Version : 0.3.0
#
# Goals:
# - Safely chmod +x shell scripts without brittle globs
# - Support recursion (optional) across your whole scripts tree
# - Dry-run mode to preview changes
# - Avoid touching files that aren't really shell scripts (optional strict)
#
# Usage:
#   ./make_executable.sh
#   ./make_executable.sh --recurse
#   ./make_executable.sh --path "CCDC Event Phases" --recurse
#   ./make_executable.sh --dry-run --recurse
#
# Options:
#   --path <DIR>     Base directory (default: current directory)
#   --recurse        Recurse into subdirectories (default: off)
#   --dry-run        Show what would change, do not chmod
#   --strict         Only chmod files that look like shell scripts
#                   (shebang contains sh/bash/zsh OR .sh extension)
#   --include <GLOB> Include pattern (default: *.sh)
#   --maxdepth <N>   If not recurse, set maxdepth (default: 1)
#   --no-color       Disable ANSI colors
# ============================================================

BASE_DIR="."
RECURSE=0
DRY_RUN=0
STRICT=0
INCLUDE_GLOB="*.sh"
MAXDEPTH=1
USE_COLOR=1

while (( $# > 0 )); do
  case "$1" in
    --path) shift; BASE_DIR="${1:-.}" ;;
    --recurse) RECURSE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --strict) STRICT=1 ;;
    --include) shift; INCLUDE_GLOB="${1:-*.sh}" ;;
    --maxdepth) shift; MAXDEPTH="${1:-1}" ;;
    --no-color) USE_COLOR=0 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--path DIR] [--recurse] [--dry-run] [--strict] [--include GLOB] [--maxdepth N] [--no-color]
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift || true
done

c() {
  local code="$1"; shift
  local text="$*"
  if [[ "$USE_COLOR" == "1" && -t 1 ]]; then
    printf "\033[%sm%s\033[0m" "$code" "$text"
  else
    printf "%s" "$text"
  fi
}

section() {
  echo ""
  echo "$(c "1;100" "============================================================")"
  echo "$(c "1;104" " $* ")"
  echo "$(c "1;100" "============================================================")"
  echo ""
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

is_shell_by_shebang() {
  # Returns 0 if first line suggests a shell interpreter
  local f="$1"
  local line=""
  line="$(head -n 1 "$f" 2>/dev/null || true)"
  [[ "$line" =~ ^#!.*(bash|sh|zsh|dash|ksh) ]]
}

is_shell_candidate() {
  local f="$1"
  # If strict: require .sh OR shell shebang
  if [[ "$STRICT" == "1" ]]; then
    [[ "$f" == *.sh ]] && return 0
    is_shell_by_shebang "$f" && return 0
    return 1
  fi
  # Non-strict: include glob already filtered; accept
  return 0
}

# Build find parameters
FIND_MAXDEPTH_ARGS=()
if [[ "$RECURSE" == "1" ]]; then
  : # no maxdepth
else
  FIND_MAXDEPTH_ARGS=(-maxdepth "${MAXDEPTH}")
fi

if ! need_cmd find; then
  echo "ERROR: find is required." >&2
  exit 1
fi

if [[ ! -d "$BASE_DIR" ]]; then
  echo "ERROR: base directory not found: $BASE_DIR" >&2
  exit 1
fi

section "Make Executable - Scan"
echo "$(c "1;92" "[*]") Base dir : $BASE_DIR"
echo "$(c "1;92" "[*]") Recurse  : $RECURSE"
echo "$(c "1;92" "[*]") Dry-run  : $DRY_RUN"
echo "$(c "1;92" "[*]") Strict   : $STRICT"
echo "$(c "1;92" "[*]") Include  : $INCLUDE_GLOB"
if [[ "$RECURSE" != "1" ]]; then
  echo "$(c "1;92" "[*]") Maxdepth : $MAXDEPTH"
fi

# Gather candidates
mapfile -t CANDIDATES < <(
  (cd "$BASE_DIR" && find . "${FIND_MAXDEPTH_ARGS[@]}" -type f -name "$INCLUDE_GLOB" -print) \
    | sed 's|^\./||'
)

if (( ${#CANDIDATES[@]} == 0 )); then
  section "Result"
  echo "$(c "1;93" "[WARN]") No matching files found."
  exit 0
fi

# Filter strict candidates if needed
FILES=()
for rel in "${CANDIDATES[@]}"; do
  f="${BASE_DIR%/}/${rel}"
  if is_shell_candidate "$f"; then
    FILES+=("$f")
  fi
done

if (( ${#FILES[@]} == 0 )); then
  section "Result"
  echo "$(c "1;93" "[WARN]") No files matched strict shell criteria."
  exit 0
fi

section "Candidates"
for f in "${FILES[@]}"; do
  if [[ -x "$f" ]]; then
    echo "$(c "1;90" "[skip]") already executable: $f"
  else
    echo "$(c "1;96" "[chmod]") will set +x:        $f"
  fi
done

# Apply
section "Apply"
if [[ "$DRY_RUN" == "1" ]]; then
  echo "$(c "1;93" "[DRY-RUN]") No changes made."
  exit 0
fi

changed=0
for f in "${FILES[@]}"; do
  if [[ -x "$f" ]]; then
    continue
  fi
  chmod +x "$f"
  changed=$((changed+1))
done

section "Done"
echo "$(c "1;92" "[OK]") Updated executable bit on $changed file(s)."
echo "$(c "1;92" "[OK]") Tip: run with --dry-run first if you’re unsure."
