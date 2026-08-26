#!/usr/bin/env bash
# Print the config for the build with every feature off.
#
# A level-one feature is switched off by a parameter. A level-two
# feature is a component, and the way to turn one off is not to mount
# it. That is what makes it level two.
#
# So this writes the whole mount list without the components, rather
# than adding to the theme's.
#
# Hugo replaces the mounts array when two configs declare one, which is
# what lets a later file take mounts away.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

printf '%s\n' "# Written by conform.sh. Do not edit."
printf '%s\n' "[params]"
# Outranks front matter, so a fixture page turning its own feature on
# does not keep it on here.
printf '%s\n' "  featuresOff = true"
printf '%s\n' "[params.features]"
for manifest in data/features/*.toml; do
  [ -e "$manifest" ] || continue
  printf '  "%s" = false\n' "$(basename "$manifest" .toml)"
done
printf '%s\n' "[module]"
for dir in layouts archetypes assets i18n static data; do
  [ -d "$dir" ] || continue
  printf '  [[module.mounts]]\n    source = "../../%s"\n    target = "%s"\n' "$dir" "$dir"
done
for dir in content assets i18n static; do
  [ -d "tools/conformance/$dir" ] || continue
  printf '  [[module.mounts]]\n    source = "%s"\n    target = "%s"\n' "$dir" "$dir"
done
