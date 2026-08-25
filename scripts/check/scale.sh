#!/usr/bin/env bash
# Build time and cacheable partials, measured on a fixture large enough
# for a per-page site query to show up. It shows up nowhere else.
set -uo pipefail
cd "$(dirname "$0")/../.."

BUDGET_SECONDS="${SCALE_BUDGET_SECONDS:-20}"
[ -d conformance/scale-content ] || python3 conformance/scripts/fixture.py --size 2000 || {
  echo "conformance/scale-content:1: could not generate the scale fixture."; exit 1; }

start="$(date +%s)"
out="$( cd conformance && hugo --config hugo.toml,config/ours/hugo.toml,config/scale/hugo.toml -d public/scale \
  --templateMetrics --templateMetricsHints --logLevel warn --gc 2>&1 )" || {
    printf '%s\n' "conformance:1: the scale build failed."
    printf '%s\n' "$out" | tail -10
    exit 1
  }
finish="$(date +%s)"
elapsed=$((finish - start))

status=0
if [ "$elapsed" -gt "$BUDGET_SECONDS" ]; then
  printf '%s\n' "conformance:1: the scale build took ${elapsed}s, over the ${BUDGET_SECONDS}s budget."
  status=1
fi
# A partial the hints mark cachable is one that returns the same markup
# every call. Leaving it uncached repeats that work once a page.
if printf '%s' "$out" | awk '/cumulative/{seen=1} seen && $NF ~ /cached/ {print}' | grep -q .; then
  printf '%s\n' "$out" | grep -i 'cached' | head -10
fi
printf '%s\n' "scale: ${elapsed}s for $(find conformance/scale-content -name '*.md' | wc -l) pages"
exit $status
