#!/usr/bin/env bash
# reads: tools/scripts/check package.txt
# Every check names the paths it reads, and every path is named.
#
# The comment checker walked tools/scripts/ and layouts/ and not
# tools/conformance/scripts/, which is as much code as either. Sixteen
# findings were sitting there and nothing said so.
#
# A gate that never walks a directory reports the same silence as one
# that walks it and finds nothing.
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"
"$PY_BIN" tools/scripts/check/coverage.py
