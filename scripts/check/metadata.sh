#!/usr/bin/env bash
# What themes.gohugo.io reads, and what a repository must not carry.
set -uo pipefail
cd "$(dirname "$0")/../.."

command -v python3 >/dev/null 2>&1 || { echo "SKIP metadata: python3 not installed"; exit 3; }
python3 scripts/check/metadata.py
