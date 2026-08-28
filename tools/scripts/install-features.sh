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
cd "$(dirname "$0")/../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"


slug="$(tools/scripts/slug.sh)"

partials=layouts/_partials
[ -d "$partials" ] || partials=layouts/partials
[ -d "$partials" ] || { echo "no partials directory" >&2; exit 1; }

mkdir -p "$partials/features" "data/$slug/features" assets/css/features
# The namespace is baked into the partial, because a partial cannot ask
# which theme it belongs to. check/namespace.sh fails if the baked name
# and the slug ever disagree.
render_slug() { sed "s|{{SLUG}}|$slug|g" "$1"; }
# feature-on.html is not installed. Only a markup render hook needs
# it, a fresh theme has none, and a partial nothing calls is an
# unused template. A theme adding a hook feature writes one.
for machinery in slot slot-map feature-set; do
  render_slug "tools/templates/feature/$machinery.html.tmpl" \
    > "$partials/$machinery.html"
done
"$PY_BIN" tools/scripts/wire-slots.py "$partials"

# The starter set is installed and switched on. A feature that ships is a
# feature a user turns off with one line, rather than one they assemble.
#
# Every shipped feature renders. Every partial is reached, so the
# unused-template check still means something.
#
# The comparison build switches them all off. It does not ask about
# unused templates, because switching them off is what leaves them
# unused.
for manifest in tools/templates/feature/manifests/*.toml; do
  [ -e "$manifest" ] || continue
  name="$(basename "$manifest" .toml)"
  cp "$manifest" "data/$slug/features/$name.toml"
  # A component renders through its shortcodes and has no partial. Its
  # stylesheet is mounted from its own directory rather than copied.
  [ -f "tools/templates/feature/partials/$name.html" ] \
    && render_slug "tools/templates/feature/partials/$name.html" > "$partials/features/$name.html"
  [ -f "tools/templates/feature/css/$name.css" ] \
    && cp "tools/templates/feature/css/$name.css" "assets/css/features/$name.css"
  true
done

# A feature that brings a script brings it here, so the asset the
# partial reaches for actually exists.
if [ -d tools/templates/feature/js ]; then
  mkdir -p assets/js
  for script in tools/templates/feature/js/*.js; do
    [ -e "$script" ] && cp "$script" "assets/js/$(basename "$script")"
  done
fi

# The words those features render.
if [ -f tools/templates/feature/i18n.toml ] && ! grep -q '^\[readingTime\]' i18n/en.toml 2>/dev/null; then
  cat tools/templates/feature/i18n.toml >> i18n/en.toml
fi

# One fixture page a feature, exercising the switch in both positions.
tools/scripts/feature-fixtures.sh

# Every feature listed in the site config with its default, commented
# out. A user sees the whole set in one place and flips a line. The
# alternative is hunting for a name written down nowhere.
if ! grep -q "params.$slug.features" hugo.toml 2>/dev/null; then
  {
    printf '\n%s\n' "# Every feature this theme ships, with the default it ships with."
    printf '%s\n' "# Uncomment a line to change it. A page may override any of them"
    printf '%s\n' "# in its own front matter."
    printf '%s\n' "# [params.$slug.features]"
    for manifest in "data/$slug/features"/*.toml; do
      [ -e "$manifest" ] || continue
      name="$(basename "$manifest" .toml)"
      default="$(sed -n 's/^ *default *= *\(true\|false\).*/\1/p' "$manifest" | head -1)"
      printf '#   %s = %s\n' "$name" "${default:-true}"
    done
  } >> hugo.toml
fi
