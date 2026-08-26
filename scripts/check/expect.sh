#!/usr/bin/env bash
# reads: conformance/content conformance/public/ours
# A fixture page may state what its own output must contain.
#
# The skeleton compares shape, and the declarations compare what a
# feature adds. Neither reads the words. A reading time rendered
# "1 minutes read" for want of an integer, and every gate passed.
set -uo pipefail
cd "$(dirname "$0")/../.."

PY_BIN="$(scripts/python.sh 2>/dev/null || echo python3)"
"$PY_BIN" scripts/check/expect.py "${1:-conformance/public/ours}"
