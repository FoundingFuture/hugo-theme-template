#!/usr/bin/env bash
# Every mark the theme draws exists in a face that can draw it.
# reads: assets/css assets/fonts layouts i18n
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

bin="$(tools/scripts/tools.sh fonttools 2>/dev/null)" || {
  echo "SKIP glyphs: fontTools is not installed. ./c setup fetches it"; exit 3; }
"$bin/python" tools/scripts/check/glyphs.py
