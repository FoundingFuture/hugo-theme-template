#!/usr/bin/env bash
# stylelint over the theme's stylesheets.
# reads: assets/css
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

[ -d assets/css ] || exit 0
command -v stylelint >/dev/null 2>&1 || {
  echo "SKIP css: stylelint not installed"; exit 3; }
# chroma.css is generated from a named Chroma style. The accessibility
# gate reads it for contrast, and house style does not apply.
#
# It is excluded in the file list rather than in the config. The list is
# resolved from here. The config is resolved from its own directory.
stylelint --config tools/stylelint.config.mjs \
  "assets/css/**/*.css" "!assets/css/chroma.css"
