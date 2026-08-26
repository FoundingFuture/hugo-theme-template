#!/usr/bin/env bash
# WCAG 2.1 AA over every built page. Contrast findings count, because a
# theme owns its colours.
set -uo pipefail
cd "$(dirname "$0")/../.."

target=conformance/public/ours
[ -d "$target" ] || { echo "SKIP a11y: no build at $target"; exit 3; }
command -v pa11y-ci >/dev/null 2>&1 || { echo "SKIP a11y: pa11y-ci not installed"; exit 3; }

# The URL list is generated. Held in the file it was empty, and pa11y-ci
# passes on nothing at all.
python="$(scripts/python.sh 2>/dev/null || echo python3)"
config=conformance/public/pa11yci.json
"$python" scripts/check/a11y-urls.py "$target" scripts/check/pa11yci.json > "$config"
pages="$("$python" -c "import json,sys;print(len(json.load(open(sys.argv[1]))['urls']))" "$config")"
if [ "$pages" -eq 0 ]; then
  printf '%s\n' "$target:1: no page to check for accessibility."
  exit 1
fi
printf '%s\n' "a11y: reading $pages pages"
pa11y-ci --config "$config"
