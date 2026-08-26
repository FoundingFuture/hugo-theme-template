#!/usr/bin/env bash
# reads: tools/conformance/public/ours
# The search index stays small enough to send, and the page works
# without the script.
#
# An index is downloaded whole by every reader who opens the search
# page. A megabyte and a half is already generous. A theme indexing the
# full text of a large site passes it without noticing.
#
# The page listing nothing in its markup is the other fault. Then the
# index is the only way to search, and a reader with the script blocked
# has an empty box.
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

BUDGET_BYTES="${SEARCH_BUDGET_BYTES:-1572864}"
target=tools/conformance/public/ours
[ -d "$target" ] || { echo "SKIP search: no build at $target"; exit 3; }

index="$target/index.json"
if [ ! -f "$index" ]; then
  printf '%s\n' "search: no index published, so the component is not mounted"
  exit 0
fi

status=0
bytes="$(wc -c < "$index" | tr -d ' ')"
if [ "$bytes" -gt "$BUDGET_BYTES" ]; then
  printf '%s\n' "$index:1: $bytes bytes, over the $BUDGET_BYTES budget."
  status=1
fi
printf '%s\n' "search: index is $bytes bytes, budget $BUDGET_BYTES"

page="$target/search/index.html"
if [ -f "$page" ]; then
  listed="$(grep -c 'class="search-result"' "$page" || true)"
  if [ "$listed" -lt 1 ]; then
    printf '%s\n' "$page:1: lists no page in its markup. Search needs the script to work."
    status=1
  else
    printf '%s\n' "search: the page lists $listed results without a script"
  fi
fi
exit $status
