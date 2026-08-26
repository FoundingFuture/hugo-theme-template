#!/usr/bin/env bash
# No third-party request. This turns the claim into a gate.
set -uo pipefail
cd "$(dirname "$0")/../.."

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. scripts/python.sh answers both questions.
PY_BIN="$(scripts/python.sh 2>/dev/null || echo python3)"

"$PY_BIN" scripts/check/external.py "${1:-conformance/public/ours}"
