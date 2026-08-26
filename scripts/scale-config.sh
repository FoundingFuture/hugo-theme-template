#!/usr/bin/env bash
# Print the config the scale build uses.
#
# Every mount goes in one file. Hugo replaces the mounts array when two
# configs both declare one, rather than joining them. A file holding
# only the scale mount would drop the theme and the fixture with it.
#
# That is what made the scale build render nothing, while still
# reporting a time.
set -euo pipefail
cd "$(dirname "$0")/.."

printf '%s\n' "# Written by scale.sh. Do not edit."
printf '%s\n' "[module]"
for dir in layouts archetypes assets i18n static data; do
  [ -d "$dir" ] || continue
  printf '  [[module.mounts]]\n    source = "../%s"\n    target = "%s"\n' "$dir" "$dir"
done
for dir in assets i18n static; do
  [ -d "conformance/$dir" ] || continue
  printf '  [[module.mounts]]\n    source = "%s"\n    target = "%s"\n' "$dir" "$dir"
done
printf '  [[module.mounts]]\n    source = "scale-content"\n    target = "content"\n'
