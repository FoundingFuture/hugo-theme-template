#!/usr/bin/env bash
# A custom front matter key at the top level collides with Hugo's own
# namespace. Hugo reserves the top level, so a custom key belongs under
# params, where it cannot clash with a future release.
# reads: tools/conformance/content
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"


command -v "$PY_BIN" >/dev/null 2>&1 || { echo "SKIP reserved: $PY_BIN not installed"; exit 3; }
"$PY_BIN" tools/scripts/check/reserved.py
