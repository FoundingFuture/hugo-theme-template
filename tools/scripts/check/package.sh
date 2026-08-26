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

command -v unzip >/dev/null 2>&1 || { echo "SKIP package: unzip not installed"; exit 3; }

slug="$(tools/scripts/slug.sh)"
tools/scripts/package.sh "$slug" >/dev/null || { echo "package.txt:1: the artefact could not be written."; exit 1; }

status=0
report() { printf '%s\n' "$1"; status=1; }

zip="$(find dist -maxdepth 1 -name "$slug-*.zip" -type f 2>/dev/null | head -1)"
[ -n "$zip" ] || { echo "dist:1: no zip was written."; exit 1; }

# One directory at the top, named for the theme. A zip that unpacks
# loose files scatters them across the site's themes directory.
tops="$(unzip -Z1 "$zip" | cut -d/ -f1 | sort -u)"
[ "$tops" = "$slug" ] || report "$zip:1: unzips to '$tops', not one directory named '$slug'."

for required in theme.toml LICENSE layouts/baseof.html; do
  unzip -Z1 "$zip" | grep -qx "$slug/$required" || \
    report "$zip:1: $required is missing. A theme carries it."
done

# What must never reach a downloader. A repository holds all of this at
# one time or another, and an include list is what keeps it out.
while IFS= read -r entry; do
  case "$entry" in
    */.git/*|*/.git|*/tmp/*|*/__pycache__/*|*/node_modules/*|*/public/*|*/resources/_gen/*|*/.lighthouseci/*)
      report "$zip:1: carries $entry, which belongs to the repository." ;;
  esac
done < <(unzip -Z1 "$zip")

# Nothing in a theme needs five megabytes. A poster or a font that big
# is a mistake somebody made once and nobody saw.
while read -r size name; do
  [ "$size" -gt 5242880 ] && report "$zip:1: $name is $((size / 1048576)) MB. Nothing in a theme is."
done < <(unzip -Z -1 -l "$zip" 2>/dev/null | awk 'NF >= 2 && $1 ~ /^[0-9]+$/ {print $1, $NF}')

printf '%s\n' "package: $(unzip -Z1 "$zip" | wc -l | tr -d ' ') paths, $(du -h "$zip" | cut -f1) zipped"
exit $status
