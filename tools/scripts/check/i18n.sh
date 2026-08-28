#!/usr/bin/env bash
# Every i18n call has a key, and every visible string is an i18n call.
# A theme that spells English inside its markup cannot be translated.
# reads: layouts i18n data
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"


command -v "$PY_BIN" >/dev/null 2>&1 || { echo "SKIP i18n: $PY_BIN not installed"; exit 3; }
"$PY_BIN" tools/scripts/check/i18n.py
