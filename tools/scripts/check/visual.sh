#!/usr/bin/env bash
# Screenshots against the last tagged release. A difference is reported
# and lands in the PR report. It does not fail the build, because a
# deliberate design change is a difference too.
# reads: tools/conformance/public/ours tools/conformance/snapshots/screens
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

command -v node >/dev/null 2>&1 || { echo "SKIP visual: node not installed"; exit 3; }

# node resolves a module from the directory it runs in, and a global
# install is nowhere near this one. Without this the gate reported
# playwright missing while it was installed, here and in CI.
if [ -z "${NODE_PATH:-}" ] && command -v npm >/dev/null 2>&1; then
  NODE_PATH="$(npm root -g 2>/dev/null || true)"
  export NODE_PATH
fi

# No baseline is not a missing tool. A repository has none until it
# tags a release. Saying SKIP made CI fail for want of a screenshot
# nobody had taken yet.
#
# Saying nothing is no better. What covers the pages until then is the
# comparison against the Hugo scaffold, which conform makes every run.
# The gate names it, rather than passing quietly.
if [ ! -d tools/conformance/snapshots/screens ]; then
  printf '%s\n' "visual: no baseline until the first release."
  printf '%s\n' "visual: compared against the Hugo scaffold instead, by conform."
  printf '%s\n' "visual: ./c release writes the baseline, or ./c snapshot does."
  exit 0
fi
node tools/conformance/scripts/visual.js
