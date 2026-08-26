#!/usr/bin/env bash
# The docs checker over everything the theme owns. A template comment
# follows the same rules as a code comment.
# reads: c tools/scripts tools/conformance/scripts layouts assets features docs README.md CHANGELOG.md
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

bin="$(tools/scripts/tools.sh writing-lint 2>/dev/null)" || {
  echo "SKIP comments: writing-lint not installed"; exit 3; }
[ -x "$bin/check-docs" ] || { echo "SKIP comments: check-docs not on PATH"; exit 3; }

targets="c"
for path in tools/scripts tools/conformance/scripts layouts assets features docs README.md CHANGELOG.md; do
  [ -e "$path" ] && targets="$targets $path"
done
# shellcheck disable=SC2086
"$bin/check-docs" $targets
