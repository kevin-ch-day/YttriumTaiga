#!/usr/bin/env bash
set -euo pipefail

# Check that live-event intel and sensitive runtime artifacts are not tracked.
# Run before pushing from event systems:
#   Scripts/verify_no_event_data.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0

warn() {
  echo "WARN: $*" >&2
  fail=1
}

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required." >&2
  exit 2
fi

tracked_files="$(git ls-files)"

blocked_paths="$(
  printf "%s\n" "$tracked_files" | awk '
    /^data\/intel\/.+/ && $0 !~ /^data\/intel\/(README\.md|\.gitkeep)$/ { print }
    /^Phase[0-9][0-9]_[^/]+\/(logs|output)\// { print }
    /(^|\/)(loot|proof|enum|tmp)\// { print }
    /(^|\/)cred_ledger\.csv$/ { print }
  '
)"

if [[ -n "$blocked_paths" ]]; then
  warn "tracked runtime/event artifacts found:"
  printf "%s\n" "$blocked_paths" >&2
fi

scan_files="$(
  git ls-files \
    'data/**' \
    '*.csv' \
    '*.txt' \
    '*.json' \
    '*.jsonl' \
    2>/dev/null \
    | awk '$0 !~ /^data\/intel\/(README\.md|\.gitkeep)$/ { print }'
)"

scan_file_array=()
if [[ -n "$scan_files" ]]; then
  while IFS= read -r file; do
    [[ -n "$file" ]] && scan_file_array+=("$file")
  done <<< "$scan_files"
fi

if (( ${#scan_file_array[@]} > 0 )) && command -v rg >/dev/null 2>&1; then
  sensitive_hits="$(
    rg -n -i \
      'set-cookie|oc sessid|ocsessid|phpsessid|begin [a-z ]*private key|aws_secret_access_key|AKIA[0-9A-Z]{16}' \
      "${scan_file_array[@]}" 2>/dev/null || true
  )"
elif (( ${#scan_file_array[@]} > 0 )); then
  sensitive_hits="$(
    grep -n -i -E \
      'set-cookie|oc sessid|ocsessid|phpsessid|begin [a-z ]*private key|aws_secret_access_key|AKIA[0-9A-Z]{16}' \
      "${scan_file_array[@]}" 2>/dev/null || true
  )"
else
  sensitive_hits=""
fi

if [[ -n "$sensitive_hits" ]]; then
  warn "tracked files contain session/secret-like markers:"
  printf "%s\n" "$sensitive_hits" >&2
fi

if [[ "$fail" -ne 0 ]]; then
  echo "FAIL: remove or sanitize tracked event data before pushing." >&2
  exit 1
fi

echo "OK: no tracked event-data paths or common session markers found."
