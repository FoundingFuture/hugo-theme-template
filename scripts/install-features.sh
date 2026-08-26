#!/usr/bin/env bash
# Put the feature mechanism into the generated layouts.
#
# The mechanism is slot.html and the slot calls that reach it. No
# feature is installed here. A feature no template renders is an unused
# template, and the static gate stops one of those.
#
# ./c feature new writes a feature. ./c feature add installs one from the
# starter set. Either way a feature arrives with its manifest, its
# partial, its stylesheet, its words and its fixture page, together.
set -euo pipefail
cd "$(dirname "$0")/.."

partials=layouts/_partials
[ -d "$partials" ] || partials=layouts/partials
[ -d "$partials" ] || { echo "no partials directory" >&2; exit 1; }

mkdir -p "$partials/features" data/features assets/css/features
cp templates/feature/slot.html "$partials/slot.html"
python3 scripts/wire-slots.py "$partials"

# The starter set is installed and switched on. A feature that ships is a
# feature a user turns off with one line, rather than one they assemble.
#
# Every shipped feature renders. Every partial is reached, so the
# unused-template check still means something. The comparison build
# switches them all off and does not ask about unused templates, because
# switching them off is what leaves them unused.
for manifest in templates/feature/manifests/*.toml; do
  [ -e "$manifest" ] || continue
  name="$(basename "$manifest" .toml)"
  cp "$manifest" "data/features/$name.toml"
  cp "templates/feature/partials/$name.html" "$partials/features/$name.html"
  [ -f "templates/feature/css/$name.css" ] \
    && cp "templates/feature/css/$name.css" "assets/css/features/$name.css"
done

# A feature that brings a script brings it here, so the asset the
# partial reaches for actually exists.
if [ -d templates/feature/js ]; then
  mkdir -p assets/js
  for script in templates/feature/js/*.js; do
    [ -e "$script" ] && cp "$script" "assets/js/$(basename "$script")"
  done
fi

# The words those features render.
if [ -f templates/feature/i18n.toml ] && ! grep -q '^\[readingTime\]' i18n/en.toml 2>/dev/null; then
  cat templates/feature/i18n.toml >> i18n/en.toml
fi

# One fixture page a feature, exercising the switch in both positions.
scripts/feature-fixtures.sh
