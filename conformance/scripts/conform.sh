#!/usr/bin/env bash
# Build the fixture twice and compare. Exits non-zero on the first gate
# that fails, so the output names one problem rather than a cascade.
set -euo pipefail
cd "$(dirname "$0")/.."

ROOT="$(cd .. && pwd -P)"
PUB=public

say() { printf '%s\n' "$*"; }
fail() { printf '%s\n' "$1" >&2; exit 1; }

# 1. The reference is regenerated every run, so it never goes stale.
say "conform: regenerating the reference"
"$ROOT/scripts/reference.sh"

# 2. Both builds, with the strict flags that turn a warning into a failure.
build() {
  local config="$1" dest="$2"
  shift 2
  rm -rf "${PUB:?}/$dest"
  hugo --config "$config" -d "$PUB/$dest" \
    --panicOnWarning --printPathWarnings \
    --printI18nWarnings --logLevel warn --gc "$@"
}
say "conform: building against the reference scaffold"
build hugo.toml,config/hugo/hugo.toml hugo --printUnusedTemplates
say "conform: building against the theme"
build hugo.toml,config/ours/hugo.toml ours --printUnusedTemplates

# Every feature off, which has to leave the theme identical to the
# scaffold. The switches are generated, so adding a feature needs no
# edit here.
#
# Unused templates are not reported for this build. Switching every
# feature off leaves every feature partial unused, by design. The build
# with the features on is where that check means something.
python3 scripts/features-off.py > config/off/hugo.toml
say "conform: building with every feature off"
build hugo.toml,config/ours/hugo.toml,config/off/hugo.toml ours-off

# 3. File list. A difference means the theme publishes a different set of
#    pages, feeds, aliases or sitemap entries than the scaffold does.
listing() {
  find "$1" -type f \
    | sed "s|^$1/||" \
    | grep -Ev '^(css|js|fonts)/|^resources/_gen' \
    | LC_ALL=C sort
}
say "conform: comparing the file list"
if ! diff -u <(listing "$PUB/hugo") <(listing "$PUB/ours") > "$PUB/files.diff" 2>&1; then
  cat "$PUB/files.diff" >&2
  fail "the theme publishes a different set of files than the scaffold."
fi

# 4. Skeleton. Same pages is not the same as the same page.
#
#    The build compared here is the one with every feature off. A
#    feature that is on is meant to change the page, and what it may
#    change is checked against its manifest in the next step.
say "conform: comparing the page skeletons"
python3 scripts/skeleton.py "$PUB/hugo" > "$PUB/skeleton-hugo.json"
python3 scripts/skeleton.py "$PUB/ours-off" > "$PUB/skeleton-ours.json"
if ! diff -u "$PUB/skeleton-hugo.json" "$PUB/skeleton-ours.json" > "$PUB/skeleton.diff" 2>&1; then
  head -60 "$PUB/skeleton.diff" >&2
  fail "with every feature off the theme still renders a different page shape."
fi

# What a feature adds is what its manifest said it would add. The
# manifests are TOML, so the reader has to be a python that reads it.
say "conform: checking the feature declarations"
feature_python="$("$ROOT/scripts/python.sh" 2>/dev/null || echo python3)"
"$feature_python" scripts/features.py \
  || fail "a feature changed something it did not declare."

say "conform: file list and skeleton agree"
