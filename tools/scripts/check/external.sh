#!/usr/bin/env bash
# No third-party request. This turns the claim into a gate.
# reads: tools/conformance/public/ours
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"

target="${1:-tools/conformance/public/ours}"
mkdir -p tools/conformance/public
# Kept for the report, which had nothing to read here before.
"$PY_BIN" tools/scripts/check/external.py "$target" | tee tools/conformance/public/external.txt
exit "${PIPESTATUS[0]}"
