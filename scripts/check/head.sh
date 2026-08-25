#!/usr/bin/env bash
# What every page owes a reader and a crawler.
set -uo pipefail
cd "$(dirname "$0")/../.."

target="${1:-conformance/public/ours}"
[ -d "$target" ] || { echo "SKIP head: no build at $target"; exit 3; }
python3 scripts/check/head.py "$target"
