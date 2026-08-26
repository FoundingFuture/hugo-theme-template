#!/usr/bin/env bash
# The tag has a changelog section with something in it.
# reads: CHANGELOG.md
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

tag="${1:-${RELEASE_TAG:-}}"
[ -n "$tag" ] || tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
[ -n "$tag" ] || { echo "SKIP changelog: no tag to check"; exit 3; }
[ -f CHANGELOG.md ] || { echo "CHANGELOG.md:1: missing."; exit 1; }

line="$(grep -n "^## ${tag}, [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\$" CHANGELOG.md | head -1 | cut -d: -f1)"
if [ -z "$line" ]; then
  printf '%s\n' "CHANGELOG.md:1: no section '## $tag, YYYY-MM-DD'."
  exit 1
fi
body="$(awk -v start="$line" 'NR > start { if ($0 ~ /^## /) exit; if (NF) print }' CHANGELOG.md)"
if [ -z "$body" ]; then
  printf '%s\n' "CHANGELOG.md:$line: the section for $tag is empty."
  exit 1
fi
exit 0
