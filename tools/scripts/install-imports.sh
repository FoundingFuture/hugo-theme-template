#!/usr/bin/env bash
# Write the scaffold's imports the way the standard config wants them.
#
# The scaffold writes a bare @import with a quoted path. The standard
# stylelint config wants url() around it. A theme shipping the bare
# form fails its own style gate on the first run.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

sheet=assets/css/main.css
[ -f "$sheet" ] || exit 0
grep -q '@import "' "$sheet" || exit 0

tmpfile="$(mktemp "$PWD/.main-css-XXXXXX")"
sed 's|@import "\([^"]*\)";|@import url("\1");|' "$sheet" > "$tmpfile"
mv "$tmpfile" "$sheet"
