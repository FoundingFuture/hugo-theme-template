#!/usr/bin/env bash
# WCAG 2.1 AA over every built page. Contrast findings count, because a
# theme owns its colours.
set -uo pipefail
cd "$(dirname "$0")/../.."

target=conformance/public/ours
[ -d "$target" ] || { echo "SKIP a11y: no build at $target"; exit 3; }
command -v pa11y-ci >/dev/null 2>&1 || { echo "SKIP a11y: pa11y-ci not installed"; exit 3; }
pa11y-ci --config scripts/check/pa11yci.json
