#!/usr/bin/env bash
# The markup is valid, and every link inside the site resolves.
# reads: conformance/public/ours
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. scripts/python.sh answers both questions.
PY_BIN="$(scripts/python.sh 2>/dev/null || echo python3)"


target=conformance/public/ours
[ -d "$target" ] || { echo "SKIP validity: no build at $target. Run ./c theme=ours."; exit 3; }

# A redirect stub carries a meta refresh and nothing else. Handing one
# to a validator asks it to judge a page that is not one.
list=conformance/public/readable.txt
mkdir -p conformance/public
"$PY_BIN" scripts/check/pages.py "$target" > "$list"
pages="$(wc -l < "$list" | tr -d ' ')"
if [ "$pages" -eq 0 ]; then
  printf '%s\n' "$target:1: no readable page to validate."
  exit 1
fi
printf '%s\n' "validity: $pages readable pages, redirects left out"

status=0
ran=0
if command -v html5validator >/dev/null 2>&1; then
  ran=1
  # shellcheck disable=SC2046
  html5validator --also-check-css $(cat "$list") || status=1
fi
if command -v htmltest >/dev/null 2>&1; then
  ran=1
  htmltest -c scripts/check/htmltest.yml "$target" || status=1
fi
if [ "$ran" -eq 0 ]; then
  echo "SKIP validity: neither html5validator nor htmltest is installed"
  exit 3
fi
"$PY_BIN" conformance/scripts/skeleton.py "$target" --assert-single-h1 --assert-description \
  >/dev/null || status=1
exit $status
