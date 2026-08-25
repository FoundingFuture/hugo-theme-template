#!/usr/bin/env bash
# No third-party request. This turns the claim into a gate.
set -uo pipefail
cd "$(dirname "$0")/../.."
python3 scripts/check/external.py "${1:-conformance/public/ours}"
