#!/usr/bin/env bash
# Print the config for the build with every feature off.
#
# A level-one feature is switched off by a parameter. A level-two
# feature is a component, and the way to turn one off is not to mount
# it. That is what makes it level two.
#
# The theme is read as a theme, the way the scaffold and a downloader
# read it. What differs from the build with the features on is the
# parameters, and the components nothing mounts.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

slug="$(tools/scripts/slug.sh)"

# A bare key after a table header belongs to that table. The two keys
# naming the theme come first, before anything opens one.
printf '%s\n' "# Written by conform.sh. Do not edit."
printf 'theme = "%s"\n' "$slug"
printf 'themesDir = "../../dist"\n'
printf '[params.%s]\n' "$slug"
# Outranks front matter. A fixture page turning its own feature on
# does not keep it on here.
printf '%s\n' "  featuresOff = true"
printf '[params.%s.features]\n' "$slug"
for manifest in "data/$slug/features"/*.toml; do
  [ -e "$manifest" ] || continue
  printf '  "%s" = false\n' "$(basename "$manifest" .toml)"
done
printf '%s\n' "[module]"
for dir in content assets i18n static; do
  [ -d "tools/conformance/$dir" ] || continue
  printf '  [[module.mounts]]\n    source = "%s"\n    target = "%s"\n' "$dir" "$dir"
done
