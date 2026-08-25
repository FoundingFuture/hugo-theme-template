#!/usr/bin/env bash
# The feeds and the sitemap are well formed, and they agree with what
# was published.
set -uo pipefail
cd "$(dirname "$0")/../.."

target=conformance/public/ours
[ -d "$target" ] || { echo "SKIP feeds: no build at $target"; exit 3; }
command -v xmllint >/dev/null 2>&1 || { echo "SKIP feeds: xmllint not installed"; exit 3; }

status=0
while IFS= read -r feed; do
  xmllint --noout "$feed" || { printf '%s\n' "$feed:1: not well formed."; status=1; }
done < <(find "$target" -name 'index.xml')
if [ -f "$target/sitemap.xml" ]; then
  xmllint --noout "$target/sitemap.xml" || {
    printf '%s\n' "$target/sitemap.xml:1: not well formed."; status=1; }
fi
python3 scripts/check/feeds.py "$target" || status=1
exit $status
