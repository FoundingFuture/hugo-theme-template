#!/usr/bin/env bash
# Screenshots against the last tagged release. A difference is reported
# and lands in the PR report. It does not fail the build, because a
# deliberate design change is a difference too.
# reads: conformance/public/ours conformance/snapshots/screens
set -uo pipefail
cd "$(dirname "$0")/../.."

command -v node >/dev/null 2>&1 || { echo "SKIP visual: node not installed"; exit 3; }

# No baseline is not a missing tool. The first run on a theme has none,
# and a release writes them. Saying SKIP made CI fail for want of a
# screenshot nobody had taken yet.
if [ ! -d conformance/snapshots/screens ]; then
  printf '%s\n' "visual: no baseline yet. ./c snapshot writes one."
  exit 0
fi
node conformance/scripts/visual.js
