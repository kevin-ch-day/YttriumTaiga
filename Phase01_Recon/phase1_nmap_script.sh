#!/usr/bin/env bash
set -euo pipefail

# Wrapper retained for compatibility.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/tools/phase1_nmap_script.sh" "$@"
