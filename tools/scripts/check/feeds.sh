#!/usr/bin/env bash
# The feeds and the sitemap are well formed, and they agree with what
# was published.
# reads: tools/conformance/public/ours
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"


target=tools/conformance/public/ours
[ -d "$target" ] || { echo "SKIP feeds: no build at $target"; exit 3; }
# The parsing and the agreement both live in feeds.py, on the standard
# library. A machine with no libxml2 runs the same check.
"$PY_BIN" tools/scripts/check/feeds.py "$target"
