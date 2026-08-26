#!/usr/bin/env bash
# Print the config for the build against the theme.
#
# The theme is consumed the way a downloader consumes it. A directory
# under a themes directory, named by the theme key. The reference
# build reads the scaffold the same way. Both sides of the comparison
# are then read as a theme, rather than as mounts into a repository.
#
# A component is not part of the theme a site adopts. The site mounts
# it. The sources below are the paths a downloader writes, with the
# artefact standing where themes/<slug>/ stands for them.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

slug="$(tools/scripts/slug.sh)"
# The glob is read from here, at the root. The path written is read by
# hugo, which runs in the fixture directory two levels down.
artefact="dist/$slug"
prefix="../.."


printf '%s\n' "# Written by conform.sh. Do not edit."
printf 'theme = "%s"\n' "$slug"
printf 'themesDir = "../../dist"\n'

# A site importing the search component adds the json output to its
# home page. That is what publishes the index. It belongs to the site
# rather than to the component, because the site decides what it
# publishes.
printf '%s\n' "[outputs]"
printf '%s\n' '  home = ["html", "rss", "json"]'

printf '%s\n' "[module]"
for component in "$artefact"/features/*/; do
  [ -d "$component" ] || continue
  for kind in layouts assets i18n; do
    [ -d "$component$kind" ] || continue
    printf '  [[module.mounts]]\n    source = "%s/%s%s"\n    target = "%s"\n' \
      "$prefix" "$component" "$kind" "$kind"
  done
done
# The content and the words the fixture supplies, as any site does.
for dir in content assets i18n static; do
  [ -d "tools/conformance/$dir" ] || continue
  printf '  [[module.mounts]]\n    source = "%s"\n    target = "%s"\n' "$dir" "$dir"
done
