#!/usr/bin/env bash
# What themes.gohugo.io needs before it will list the theme. Required to
# release, not required to develop.
# reads: theme.toml README.md images
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. scripts/python.sh answers both questions.
PY_BIN="$(scripts/python.sh 2>/dev/null || echo python3)"


command -v "$PY_BIN" >/dev/null 2>&1 || { echo "SKIP listing: $PY_BIN not installed"; exit 3; }
"$PY_BIN" scripts/check/metadata.py --listing
