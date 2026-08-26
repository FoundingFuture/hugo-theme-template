#!/usr/bin/env bash
# Build time and cacheable partials, measured on a fixture large enough
# for a per-page site query to show up. It shows up nowhere else.
set -uo pipefail
cd "$(dirname "$0")/../.."

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. scripts/python.sh answers both questions.
PY_BIN="$(scripts/python.sh 2>/dev/null || echo python3)"


BUDGET_SECONDS="${SCALE_BUDGET_SECONDS:-20}"
[ -d conformance/scale-content ] || "$PY_BIN" conformance/scripts/fixture.py --size 2000 || {
  echo "conformance/scale-content:1: could not generate the scale fixture."; exit 1; }

mkdir -p conformance/config/scale
scripts/scale-config.sh > conformance/config/scale/hugo.toml

start="$(date +%s)"
out="$( cd conformance && hugo --config hugo.toml,config/scale/hugo.toml -d public/scale \
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
# A partial the hints mark cachable returns the same markup every call.
# Leaving it uncached repeats that work once a page, which is invisible
# on twenty pages and expensive on two thousand.
#
# The metrics table carries a cache potential column and a cached
# column. A partial with potential and no caching is the finding.
printf '%s\n' "$out" > conformance/public/metrics.txt
# The table is printed either way. The exit code, not the output, says
# whether anything is wrong with it.
if ! "$PY_BIN" scripts/check/metrics.py conformance/public/metrics.txt; then
  status=1
fi
# The count is what was published, not what was written. A build that
# renders nothing used to report the pages it was given and pass.
pages="$(find conformance/public/scale -name '*.html' | wc -l | tr -d ' ')"
if [ "$pages" -lt 100 ]; then
  printf '%s\n' "conformance:1: the scale build published $pages pages. It is not building the fixture."
  exit 1
fi
printf '%s\n' "scale: ${elapsed}s for ${pages} pages"

# The report reads this on every run. Twenty seconds is a ceiling. A
# scaffold finishing in one says nothing about the theme that will
# replace it. The measured number is what shows a backport its own
# cost, the day its own templates land.
mkdir -p conformance/public
printf '%s\t%s\t%s\n' "$elapsed" "$pages" "$BUDGET_SECONDS" \
  > conformance/public/scale.txt
exit $status
