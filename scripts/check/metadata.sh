#!/usr/bin/env bash
# What themes.gohugo.io reads, and what a repository must not carry.
set -uo pipefail
cd "$(dirname "$0")/../.."

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. scripts/python.sh answers both questions.
PY_BIN="$(scripts/python.sh 2>/dev/null || echo python3)"


command -v "$PY_BIN" >/dev/null 2>&1 || { echo "SKIP metadata: "$PY_BIN" not installed"; exit 3; }
"$PY_BIN" scripts/check/metadata.py
