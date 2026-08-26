#!/usr/bin/env bash
# No third-party request. This turns the claim into a gate.
# reads: conformance/public/ours
set -uo pipefail
cd "$(dirname "$0")/../.."

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. scripts/python.sh answers both questions.
PY_BIN="$(scripts/python.sh 2>/dev/null || echo python3)"

target="${1:-conformance/public/ours}"
mkdir -p conformance/public
# Kept for the report, which had nothing to read here before.
"$PY_BIN" scripts/check/external.py "$target" | tee conformance/public/external.txt
exit "${PIPESTATUS[0]}"
