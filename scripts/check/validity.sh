#!/usr/bin/env bash
# The markup is valid, and every link inside the site resolves.
set -uo pipefail
cd "$(dirname "$0")/../.."

target=conformance/public/ours
[ -d "$target" ] || { echo "SKIP validity: no build at $target. Run ./c theme=ours."; exit 3; }

status=0
ran=0
if command -v html5validator >/dev/null 2>&1; then
  ran=1
  html5validator --root "$target" --also-check-css || status=1
fi
if command -v htmltest >/dev/null 2>&1; then
  ran=1
  htmltest -c scripts/check/htmltest.yml "$target" || status=1
fi
if [ "$ran" -eq 0 ]; then
  echo "SKIP validity: neither html5validator nor htmltest is installed"
  exit 3
fi
python3 conformance/scripts/skeleton.py "$target" --assert-single-h1 --assert-description \
  >/dev/null || status=1
exit $status
