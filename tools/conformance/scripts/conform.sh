#!/usr/bin/env bash
# Build the fixture twice and compare. Exits non-zero on the first gate
# that fails, so the output names one problem rather than a cascade.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1



ROOT="$(cd ../.. && pwd -P)"
# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$("$ROOT/tools/scripts/python.sh" 2>/dev/null || echo python3)"
PUB=public

say() { printf '%s\n' "$*"; }
fail() { printf '%s\n' "$1" >&2; exit 1; }

# 1. The artefact, and the configs that read it. Both builds then read
#    a theme directory: the scaffold's, and this theme's package.
say "conform: writing the artefact and the configs"
"$ROOT/tools/scripts/configs.sh"

# 2. The reference is regenerated every run, so it never goes stale.
say "conform: regenerating the reference"
"$ROOT/tools/scripts/reference.sh"

# 3. Both builds, with the strict flags that turn a warning into a failure.
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
# The directory is gitignored, because the file in it is generated. A
# fresh clone therefore does not have it yet.
say "conform: building with every feature off"
build hugo.toml,config/off/hugo.toml ours-off

# 4. File list. A difference means the theme publishes a different set of
#    pages, feeds, aliases or sitemap entries than the scaffold does.
listing() {
  find "$1" -type f \
    | sed "s|^$1/||" \
    | grep -Ev '^(css|js|fonts)/|^resources/_gen' \
    | LC_ALL=C sort
}
# The build compared here has every feature off, for the same reason
# the skeleton gate uses it. A feature may publish a file of its own,
# such as a search index. What it may publish is checked against its
# manifest further down.
say "conform: comparing the file list"
if ! diff -u <(listing "$PUB/hugo") <(listing "$PUB/ours-off") > "$PUB/files.diff" 2>&1; then
  cat "$PUB/files.diff" >&2
  fail "with every feature off the theme publishes a different set of files."
fi

# 4. Skeleton. Same pages is not the same as the same page.
#
#    The build compared here has every feature off. A feature that is
#    on is meant to change the page. What it may change is checked
#    against its manifest in the next step.
say "conform: comparing the page skeletons"
"$PY_BIN" scripts/skeleton.py "$PUB/hugo" > "$PUB/skeleton-hugo.json"
"$PY_BIN" scripts/skeleton.py "$PUB/ours-off" > "$PUB/skeleton-ours.json"
if ! diff -u "$PUB/skeleton-hugo.json" "$PUB/skeleton-ours.json" > "$PUB/skeleton.diff" 2>&1; then
  head -60 "$PUB/skeleton.diff" >&2
  fail "with every feature off the theme still renders a different page shape."
fi

# The h1 of every page survives what bootstrap does to the scaffold.
say "conform: comparing the h1 of every page"
"$PY_BIN" scripts/h1-agree.py || fail "the theme and the reference disagree on an h1."

# What a feature adds is what its manifest said it would add. The
# manifests are TOML, so the reader has to be a python that reads it.
say "conform: checking the feature declarations"
feature_python="$("$ROOT/tools/scripts/python.sh" 2>/dev/null || echo python3)"
"$feature_python" scripts/features.py \
  || fail "a feature changed something it did not declare."

say "conform: file list and skeleton agree"
