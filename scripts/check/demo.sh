#!/usr/bin/env bash
# The demo is the fixture built against the theme, under /demo/.
set -uo pipefail
cd "$(dirname "$0")/../.."

scripts/reference.sh || exit 1
( cd conformance && hugo --config hugo.toml,config/ours/hugo.toml -d public/demo \
    --baseURL "${DEMO_URL:-https://example.org/demo/}" \
    --panicOnWarning --logLevel warn --gc ) >/dev/null 2>&1 || {
  echo "conformance:1: the demo build failed."
  exit 1
}
demosite="$(sed -n 's/^ *demosite *= *"\([^"]*\)".*/\1/p' theme.toml | head -1)"
[ -n "$demosite" ] || { echo "theme.toml:1: demosite is empty, so the demo has no address."; exit 1; }
exit 0
