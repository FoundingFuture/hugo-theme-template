#!/usr/bin/env bash
# eslint over the theme's scripts, when it has any.
set -uo pipefail
cd "$(dirname "$0")/../.."

[ -d assets/js ] || exit 0
command -v eslint >/dev/null 2>&1 || {
  echo "SKIP js: eslint not installed"; exit 3; }
eslint --config eslint.config.mjs assets/js
