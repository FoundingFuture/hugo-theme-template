#!/usr/bin/env bash
# Give every page an anchor at the top of it.
#
# The back-to-top feature links to #top, and nothing carried that id, so
# the link went nowhere. htmltest found it, having been given the site
# for the first time.
#
# The id goes on the body, which is outside the page skeleton, so the
# comparison against the reference is unaffected.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

target=layouts/baseof.html
[ -f "$target" ] || exit 0
grep -q 'id="top"' "$target" && exit 0

tmpfile="$(mktemp "$PWD/.baseof-XXXXXX")"
sed 's|^<body>$|<body id="top">|' "$target" > "$tmpfile"
mv "$tmpfile" "$target"
