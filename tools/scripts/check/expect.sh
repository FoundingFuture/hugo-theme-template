#!/usr/bin/env bash
# reads: tools/conformance/content tools/conformance/public/ours
# A fixture page may state what its own output must contain.
#
# The skeleton compares shape, and the declarations compare what a
# feature adds. Neither reads the words. A reading time rendered
# "1 minutes read" for want of an integer, and every gate passed.
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"
"$PY_BIN" tools/scripts/check/expect.py "${1:-tools/conformance/public/ours}"
