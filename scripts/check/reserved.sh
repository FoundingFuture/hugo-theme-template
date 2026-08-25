#!/usr/bin/env bash
# A custom front matter key at the top level collides with Hugo's own
# namespace. Hugo reserves the top level, so a custom key belongs under
# params, where it cannot clash with a future release.
set -uo pipefail
cd "$(dirname "$0")/../.."

command -v python3 >/dev/null 2>&1 || { echo "SKIP reserved: python3 not installed"; exit 3; }
python3 scripts/check/reserved.py
