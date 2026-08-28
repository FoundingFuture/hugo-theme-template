#!/usr/bin/env bash
# Static analysis over every script the template owns.
#
# The first word of this comment is not the tool's name. A comment
# opening with that word is read as a directive, and the file then
# fails to parse. The gate could not read its own script.
# reads: c tools/scripts tools/conformance/scripts
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

bin="$(tools/scripts/tools.sh shellcheck 2>/dev/null)" && PATH="$bin:$PATH"
command -v shellcheck >/dev/null 2>&1 || {
  echo "SKIP shellcheck: not installed. ./c setup fetches it"; exit 3; }

files="c"
for file in tools/scripts/*.sh tools/scripts/check/*.sh tools/conformance/scripts/*.sh; do
  [ -f "$file" ] && files="$files $file"
done
# shellcheck disable=SC2086
shellcheck --shell=bash --severity=style $files
