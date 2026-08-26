#!/usr/bin/env bash
# Write the artefact: dist/<slug>/, and dist/<slug>-<version>.zip.
#
# That directory is what a downloader unzips into themes/<slug>/. It
# is what everything else consumes too. The fixture builds on it, the
# demo builds on it, the release attaches it, and the install gate
# unzips it. Nothing reads this repository as a theme.
#
# What goes in is named in package.txt, one path per line. Data, not
# code, so shipping a new directory is an edit to a list.
# reads: package.txt theme.toml
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

[ -f package.txt ] || { printf '%s\n' "package.txt is missing." >&2; exit 1; }

slug="${1:-$(tools/scripts/slug.sh)}"
version="${RELEASE_TAG:-$(git describe --tags --abbrev=0 2>/dev/null || true)}"
[ -n "$version" ] || version="v0.0.0-dev"

dest="dist/$slug"
rm -rf "${dest:?}"
mkdir -p "$dest"

shipped=0
while read -r verb path; do
  case "$verb" in ""|\#*) continue ;; esac  # docs-style:ignore
  [ "$verb" = ship ] || continue
  # A theme need not carry every shipped path. The images arrive when
  # somebody takes the screenshots, and the listing gate is what asks
  # for them.
  [ -e "$path" ] || continue
  cp -R "$path" "$dest/"
  shipped=$((shipped + 1))
done < <(sed 's/#.*//' package.txt)

[ "$shipped" -gt 0 ] || { printf '%s\n' "package.txt ships nothing." >&2; exit 1; }

# Every zip for this theme goes, including the ones an earlier version
# left. The release attaches dist/*.zip, and a stale zip would ride
# along with the one this run wrote.
zip="dist/$slug-$version.zip"
rm -f dist/"$slug"-*.zip
# Written by Python rather than by zip, which Git for Windows does not
# ship. One less thing to install, and one less row in the table of
# what a theme author needs.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"
"$PY_BIN" tools/scripts/archive.py write "$dest" "$zip" || {
  printf '%s\n' "package: $PY_BIN could not write $zip" >&2
  exit 1
}

printf '%s\n' "$dest"
