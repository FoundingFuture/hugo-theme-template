#!/usr/bin/env bash
# stylelint over the theme's stylesheets.
# reads: assets/css
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

[ -d assets/css ] || exit 0
command -v stylelint >/dev/null 2>&1 || {
  echo "SKIP css: stylelint not installed"; exit 3; }
stylelint --config stylelint.config.mjs "assets/css/**/*.css"
