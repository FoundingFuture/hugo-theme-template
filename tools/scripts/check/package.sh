#!/usr/bin/env bash
# The artefact, before anything consumes it. It exists, and it unzips
# to one directory named for the theme. It carries what a theme must
# carry, and nothing a downloader should never receive.
#
# The install gate is what builds a site on it. This one only asks what
# is in the box.
# reads: package.txt dist
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

# Git Bash has python and not python3, and reading a zip needs a
# reader either way. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"
command -v "$PY_BIN" >/dev/null 2>&1 || { echo "SKIP package: $PY_BIN not installed"; exit 3; }

slug="$(tools/scripts/slug.sh)"
tools/scripts/package.sh "$slug" >/dev/null || { echo "package.txt:1: the artefact could not be written."; exit 1; }

status=0
report() { printf '%s\n' "$1"; status=1; }

zip="$(find dist -maxdepth 1 -name "$slug-*.zip" -type f 2>/dev/null | head -1)"
[ -n "$zip" ] || { echo "dist:1: no zip was written."; exit 1; }

# The listing, read once.
#
# The rule: no grep -q on the right of a pipe under pipefail. It bites
# when the left side writes more than one line. The writer takes
# SIGPIPE once grep leaves on its first match, and the pipeline hands
# back 141 rather than the match.
#
# This asked whether theme.toml was in the zip and was told 141. It
# reported the file missing while it sat right there. Whether that
# happens depends on how the writer buffers, so it passed on one
# machine and failed on the next.
listing="$("$PY_BIN" tools/scripts/archive.py list "$zip")"

# One directory at the top, named for the theme. A zip that unpacks
# loose files scatters them across the site's themes directory.
tops="$(printf '%s\n' "$listing" | cut -d/ -f1 | sort -u)"
[ "$tops" = "$slug" ] || report "$zip:1: unzips to '$tops', not one directory named '$slug'."

for required in theme.toml LICENSE layouts/baseof.html; do
  case $'\n'"$listing"$'\n' in
    *$'\n'"$slug/$required"$'\n'*) ;;
    *) report "$zip:1: $required is missing. A theme carries it." ;;
  esac
done

# What must never reach a downloader. A repository holds all of this at
# one time or another, and an include list is what keeps it out.
while IFS= read -r entry; do
  case "$entry" in
    */.git/*|*/.git|*/tmp/*|*/__pycache__/*|*/node_modules/*|*/public/*|*/resources/_gen/*|*/.lighthouseci/*)
      report "$zip:1: carries $entry, which belongs to the repository." ;;
  esac
done <<< "$listing"

# Nothing in a theme needs five megabytes. A poster or a font that big
# is a mistake somebody made once and nobody saw.
while read -r size name; do
  [ "$size" -gt 5242880 ] && report "$zip:1: $name is $((size / 1048576)) MB. Nothing in a theme is."
done < <("$PY_BIN" tools/scripts/archive.py sizes "$zip")

printf '%s\n' "package: $(printf '%s\n' "$listing" | wc -l | tr -d ' ') paths, $(du -h "$zip" | cut -f1) zipped"
exit $status
