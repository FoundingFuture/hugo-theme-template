#!/usr/bin/env bash
# A feature arrives whole or not at all. Manifest, partial, stylesheet,
# words, and a fixture page for the on state and the off state.
set -uo pipefail
cd "$(dirname "$0")/../.."

python="$(scripts/python.sh)" || { echo "SKIP features: no python"; exit 3; }
"$python" scripts/check/features.py
