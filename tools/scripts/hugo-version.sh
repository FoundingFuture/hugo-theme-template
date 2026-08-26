#!/usr/bin/env bash
# Print the installed Hugo version as x.y.z, and nothing else.
set -euo pipefail

command -v hugo >/dev/null 2>&1 || { echo "hugo is not on PATH" >&2; exit 3; }
hugo version | sed -n 's/^hugo v\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' | head -1
