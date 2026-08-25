#!/usr/bin/env bash
# Lighthouse over four representative pages. Chrome is needed, so this
# gate runs in CI and nowhere else.
set -uo pipefail
cd "$(dirname "$0")/../.."

command -v lhci >/dev/null 2>&1 || { echo "SKIP perf: lighthouse-ci not installed"; exit 3; }
[ -d conformance/public/ours ] || { echo "SKIP perf: no build"; exit 3; }
lhci autorun --config=lighthouserc.json
