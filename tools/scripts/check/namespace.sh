#!/usr/bin/env bash
# Everything this theme reads sits under one namespace, and that
# namespace is the slug.
#
# Hugo merges a theme's data and params into the site's, and the site
# wins. A theme reading params.features or data/features is a theme a
# site silently overrides by having either of its own. Hugo asks theme
# authors to namespace both, and this holds them to it.
#
# The namespace is written into the generated partials, because a
# partial cannot ask which theme it belongs to. That makes it a second
# spelling of a name defined in slug.sh, and a second spelling is the
# one that goes stale. This is the test that stops it.
#
# reads: data layouts theme.toml
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

slug="$(tools/scripts/slug.sh)"
status=0

# One namespace under data/, named for the slug.
found=""
for folder in data/*/features; do
  [ -d "$folder" ] || continue
  found="$found $folder"
done
if [ -z "$found" ]; then
  if [ -d data/features ]; then
    echo "data/features:1: not namespaced. Hugo merges it into the site's data, and the site wins."
    status=1
  fi
else
  for folder in $found; do
    name="${folder#data/}"
    name="${name%/features}"
    if [ "$name" != "$slug" ]; then
      echo "$folder:1: namespace is '$name', and the theme installs as '$slug'."
      status=1
    fi
  done
fi

# The generated partials name the same one.
partials=layouts/_partials
[ -d "$partials" ] || partials=layouts/partials
for file in "$partials/slot.html" "$partials/head/css.html"; do
  [ -f "$file" ] || continue
  if grep -q 'hugo\.Data\.features\|site\.Params\.features\|Params\.featuresoff' "$file"; then
    echo "$file:1: reads a top-level key. It belongs under the '$slug' namespace."
    status=1
  fi
  if grep -q '{{SLUG}}' "$file"; then
    echo "$file:1: the namespace placeholder was never substituted."
    status=1
  fi
  if grep -q 'index hugo.Data\|index site.Params' "$file" && ! grep -q "\"$slug\"" "$file"; then
    echo "$file:1: names a namespace that is not '$slug'."
    status=1
  fi
done

[ "$status" -eq 0 ] && printf '%s\n' "namespace: data and params sit under '$slug'"
exit $status
