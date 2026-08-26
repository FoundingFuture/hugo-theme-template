#!/usr/bin/env bash
# The theme builds under the pinned Hugo and under the newest one. A
# release that only works on the author's version is not a release.
# reads: tools/conformance
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

if ! command -v hugo-latest >/dev/null 2>&1; then
  echo "SKIP versions: hugo-latest not on PATH. CI installs both."
  exit 3
fi
status=0
for binary in hugo hugo-latest; do
  if ! ( cd tools/conformance && "$binary" --config hugo.toml,config/ours/hugo.toml \
      -d "public/version-$binary" --panicOnWarning --logLevel warn --gc ) >/dev/null 2>&1; then
    printf '%s\n' "conformance:1: the theme does not build under $binary."
    status=1
  fi
done
exit $status
