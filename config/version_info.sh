#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${CONFIG_DIR}/version.conf"

echo "YttriumTaiga v${YTT_APP_VERSION} (${YTT_VERSION_DATE})"
