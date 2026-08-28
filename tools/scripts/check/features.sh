#!/usr/bin/env bash
# A feature arrives whole or not at all. Manifest, partial, stylesheet,
# words, and a fixture page for the on state and the off state.
# reads: data layouts tools/templates/feature tools/conformance/content/kitchen-sink/features
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

python="$(tools/scripts/python.sh)" || { echo "SKIP features: no python"; exit 3; }
"$python" tools/scripts/check/features.py
