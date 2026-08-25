#!/usr/bin/env bash
# What themes.gohugo.io needs before it will list the theme. Required to
# release, not required to develop.
set -uo pipefail
cd "$(dirname "$0")/../.."

command -v python3 >/dev/null 2>&1 || { echo "SKIP listing: python3 not installed"; exit 3; }
python3 scripts/check/metadata.py --listing
