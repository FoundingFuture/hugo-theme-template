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
