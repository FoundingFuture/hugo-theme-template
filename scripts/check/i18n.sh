#!/usr/bin/env bash
# Every i18n call has a key, and every visible string is an i18n call.
# A theme that spells English inside its markup cannot be translated.
set -uo pipefail
cd "$(dirname "$0")/../.."

command -v python3 >/dev/null 2>&1 || { echo "SKIP i18n: python3 not installed"; exit 3; }
python3 scripts/check/i18n.py
