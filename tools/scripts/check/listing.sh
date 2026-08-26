#!/usr/bin/env bash
# What themes.gohugo.io needs before it will list the theme. Required to
# release, not required to develop.
# reads: theme.toml README.md images dist
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"

tools/scripts/package.sh >/dev/null || { echo "listing: the artefact could not be written."; exit 1; }


command -v "$PY_BIN" >/dev/null 2>&1 || { echo "SKIP listing: $PY_BIN not installed"; exit 3; }
"$PY_BIN" tools/scripts/check/metadata.py --listing
