#!/usr/bin/env bash
# YttriumTaiga core kernel loader.

# Source-safe: callers own shell options. This is the canonical shared layer for
# repo-level utilities and the migration target for phase-local scripts.

YT_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${YT_CORE_DIR}/errors.sh"
# shellcheck disable=SC1091
source "${YT_CORE_DIR}/display.sh"
# shellcheck disable=SC1091
source "${YT_CORE_DIR}/paths.sh"
# shellcheck disable=SC1091
source "${YT_CORE_DIR}/validate.sh"

yt_core_loaded() {
  return 0
}
