#!/usr/bin/env bash
# Print the config serve reads: the repository mounted directly.
#
# Everything else reads the artefact, which needs a repack after every
# edit. Live reload cannot wait for that, so serve states the trade
# rather than hiding it. A bug that appears only under serve is a bug
# in the mounts below.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

printf '%s\n' "# Written by configs.sh. Do not edit."
printf '%s\n' '[outputs]'
printf '%s\n' '  home = ["html", "rss", "json"]'
printf '%s\n' "[module]"
for dir in layouts archetypes assets i18n static data; do
  [ -d "$dir" ] || continue
  printf '  [[module.mounts]]\n    source = "../../%s"\n    target = "%s"\n' "$dir" "$dir"
done
for component in features/*/; do
  [ -d "$component" ] || continue
  for kind in layouts assets i18n; do
    [ -d "$component$kind" ] || continue
    printf '  [[module.mounts]]\n    source = "../../%s%s"\n    target = "%s"\n' \
      "$component" "$kind" "$kind"
  done
done
for dir in content assets i18n static; do
  [ -d "tools/conformance/$dir" ] || continue
  printf '  [[module.mounts]]\n    source = "%s"\n    target = "%s"\n' "$dir" "$dir"
done
