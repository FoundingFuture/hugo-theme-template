#!/usr/bin/env bash
# What themes.gohugo.io reads, and what a repository must not carry.
# reads: theme.toml hugo.toml README.md LICENSE .hugo-version images dist
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"

tools/scripts/package.sh >/dev/null || { echo "metadata: the artefact could not be written."; exit 1; }


command -v "$PY_BIN" >/dev/null 2>&1 || { echo "SKIP metadata: $PY_BIN not installed"; exit 3; }
"$PY_BIN" tools/scripts/check/metadata.py
