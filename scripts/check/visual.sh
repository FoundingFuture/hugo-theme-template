#!/usr/bin/env bash
# Screenshots against the last tagged release. A difference is reported
# and lands in the PR report. It does not fail the build, because a
# deliberate design change is a difference too.
set -uo pipefail
cd "$(dirname "$0")/../.."

command -v npx >/dev/null 2>&1 || { echo "SKIP visual: node and npx not installed"; exit 3; }
[ -d conformance/snapshots/screens ] || {
  echo "SKIP visual: no screenshots yet. Run ./c snapshot."; exit 3; }
node conformance/scripts/visual.js
