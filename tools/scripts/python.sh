#!/usr/bin/env bash
# Print a python that can read TOML.
#
# tomllib arrived in 3.11. Below that a tools venv carrying tomli is
# used when one is present. Nothing installs one, so a Python under
# 3.11 needs tomli put there by hand.
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

for candidate in $candidates; do
  command -v "$candidate" >/dev/null 2>&1 && { command -v "$candidate"; exit 0; }
done
exit 3
