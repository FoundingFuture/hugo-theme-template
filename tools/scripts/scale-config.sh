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
cd "$(dirname "$0")/../.." || exit 1

slug="$(tools/scripts/slug.sh)"
# The glob is read from the root, the path from the fixture directory.
artefact="dist/$slug"
prefix="../.."


printf '%s\n' "# Written by scale.sh. Do not edit."
printf 'theme = "%s"\n' "$slug"
printf 'themesDir = "../../dist"\n'
printf '%s\n' "[module]"
# The components, so the scale build renders what the ours build
# renders. An installed feature whose partial is not mounted is a build
# error. The scale fixture is where that showed up.
for component in "$artefact"/features/*/; do
  [ -d "$component" ] || continue
  for dir in layouts assets i18n; do
    [ -d "$component$dir" ] || continue
    printf '  [[module.mounts]]\n    source = "%s/%s%s"\n    target = "%s"\n' \
      "$prefix" "$component" "$dir" "$dir"
  done
done
for dir in assets i18n static; do
  [ -d "tools/conformance/$dir" ] || continue
  printf '  [[module.mounts]]\n    source = "%s"\n    target = "%s"\n' "$dir" "$dir"
done
printf '  [[module.mounts]]\n    source = "scale-content"\n    target = "content"\n'
