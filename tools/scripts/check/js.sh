#!/usr/bin/env bash
# eslint over the theme's scripts, when it has any.
# reads: assets/js
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

[ -d assets/js ] || exit 0
bin="$(tools/scripts/tools.sh eslint 2>/dev/null)" && PATH="$bin:$PATH"
command -v eslint >/dev/null 2>&1 || {
  echo "SKIP js: eslint not installed. ./c setup fetches it"; exit 3; }
eslint --config tools/eslint.config.mjs assets/js
