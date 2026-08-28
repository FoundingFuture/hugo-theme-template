#!/usr/bin/env bash
# The example site builds, the way somebody who downloaded the theme
# would build it.
#
# themes.gohugo.io reads exampleSite/ to make the demo, and a reviewer
# opens it before anything else. A theme whose own example site does not
# build is a theme nobody sees working.
#
# The artefact is unzipped into themes/<slug>, which is the one path a
# downloader takes. Mounting the sources instead would test a layout
# arrangement no user has.
#
# reads: dist exampleSite theme.toml
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

[ -d exampleSite ] || { echo "SKIP example: no exampleSite/"; exit 3; }

slug="$(tools/scripts/slug.sh)"
artefact="dist/$slug"
[ -d "$artefact" ] || { echo "SKIP example: no artefact at $artefact. ./c package writes it"; exit 3; }

status=0

# The theme key names the directory the theme installs into. That name
# comes from slug.sh, in one place, and a config that disagrees with it
# builds here and fails for everybody else.
declared="$(sed -n "s/^ *theme *= *['\"]\\([^'\"]*\\)['\"].*/\\1/p" exampleSite/hugo.toml | head -1)"
if [ -z "$declared" ]; then
  echo "exampleSite/hugo.toml:1: no theme key, so the example site does not name the theme."
  status=1
elif [ "$declared" != "$slug" ]; then
  echo "exampleSite/hugo.toml:1: theme is '$declared', and the theme installs as '$slug'."
  status=1
fi

work=.example-check
rm -rf "$work"
mkdir -p "$work/themes"
cp -R exampleSite/. "$work/"
rm -rf "$work/themes/$slug"
cp -R "$artefact" "$work/themes/$slug"

if ! out="$( ( cd "$work" && hugo --renderToMemory --panicOnWarning --logLevel warn --gc ) 2>&1 )"; then
  echo "exampleSite/hugo.toml:1: the example site does not build against the artefact."
  printf '%s\n' "$out" | grep -iE 'ERROR|WARN|found no layout' | head -5
  status=1
else
  pages="$(printf '%s' "$out" | sed -n 's/^ *Pages *│ *\([0-9]*\).*/\1/p' | head -1)"
  printf '%s\n' "example: the example site builds against $artefact, ${pages:-0} pages"
fi

rm -rf "$work"
exit $status
