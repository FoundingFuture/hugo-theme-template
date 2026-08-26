#!/usr/bin/env bash
# What every page owes a reader and a crawler.
# reads: tools/conformance/public/ours
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"


target="${1:-tools/conformance/public/ours}"
[ -d "$target" ] || { echo "SKIP head: no build at $target"; exit 3; }
"$PY_BIN" tools/scripts/check/head.py "$target"
