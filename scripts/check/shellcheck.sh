#!/usr/bin/env bash
# shellcheck over every script the template owns.
set -uo pipefail
cd "$(dirname "$0")/../.."

command -v shellcheck >/dev/null 2>&1 || {
  echo "SKIP shellcheck: shellcheck not installed"; exit 3; }

files="c"
for file in scripts/*.sh scripts/check/*.sh conformance/scripts/*.sh; do
  [ -f "$file" ] && files="$files $file"
done
# shellcheck disable=SC2086
shellcheck --shell=bash --severity=style $files
