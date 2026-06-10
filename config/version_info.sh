#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${CONFIG_DIR}/version.conf"

echo "Taconite v${TACONITE_APP_VERSION} (${TACONITE_VERSION_DATE})"
