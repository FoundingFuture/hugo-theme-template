#!/usr/bin/env bash
# Generate contract.toml and docs/front-matter.md from the templates.
#
# The contract is what the theme reads and what it defines. It is
# generated, never written by hand, so it cannot drift from the markup.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"


"$PY_BIN" tools/scripts/contract.py "$@"
