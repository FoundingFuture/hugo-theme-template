#!/usr/bin/env bash
# The mounts prove the templates. The module import proves the path a
# user actually takes to install the theme.
set -uo pipefail
cd "$(dirname "$0")/../.."

command -v go >/dev/null 2>&1 || { echo "SKIP module: go not installed"; exit 3; }
( cd conformance && hugo mod verify && hugo mod graph ) >/dev/null 2>&1 || {
  echo "conformance:1: hugo mod verify or graph failed."
  exit 1
}
