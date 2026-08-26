#!/usr/bin/env bash
# Print a python that can read TOML.
#
# tomllib arrived in 3.11. Below that the tools venv carries tomli,
# because writing-lint depends on it there. The pipeline has a reader
# either way, so no check is skipped for the want of one.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

candidates="python3 python"
for candidate in $candidates; do
  command -v "$candidate" >/dev/null 2>&1 || continue
  if "$candidate" -c 'import tomllib' >/dev/null 2>&1; then
    command -v "$candidate"
    exit 0
  fi
done

venv=tools/.deps/venv
reads_toml() {
  [ -x "$1" ] || return 1
  "$1" -c 'import tomllib' >/dev/null 2>&1 && return 0
  "$1" -c 'import tomli' >/dev/null 2>&1
}

if reads_toml "$venv/bin/python"; then
  ( cd "$venv/bin" && pwd -P | sed 's|$|/python|' )
  exit 0
fi
if tools/scripts/tools.sh writing-lint >/dev/null 2>&1 && reads_toml "$venv/bin/python"; then
  ( cd "$venv/bin" && pwd -P | sed 's|$|/python|' )
  exit 0
fi

for candidate in $candidates; do
  command -v "$candidate" >/dev/null 2>&1 && { command -v "$candidate"; exit 0; }
done
exit 3
