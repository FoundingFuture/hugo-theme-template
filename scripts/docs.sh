#!/usr/bin/env bash
# Generate contract.toml and docs/front-matter.md from the templates.
#
# The contract is what the theme reads and what it defines. It is
# generated, never written by hand, so it cannot drift from the markup.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/contract.py "$@"
