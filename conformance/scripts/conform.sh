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
  rm -rf "${PUB:?}/$dest"
  hugo --config "$config" -d "$PUB/$dest" \
    --panicOnWarning --printPathWarnings --printUnusedTemplates \
    --printI18nWarnings --logLevel warn --gc
}
say "conform: building against the reference scaffold"
build hugo.toml,config/hugo/hugo.toml hugo
say "conform: building against the theme"
build hugo.toml,config/ours/hugo.toml ours

# 3. File list. A difference means the theme publishes a different set of
#    pages, feeds, aliases or sitemap entries than the scaffold does.
listing() {
  find "$1" -type f \
    | sed "s|^$1/||" \
    | grep -Ev '^(css|js|fonts)/|^resources/_gen' \
    | LC_ALL=C sort
}
say "conform: comparing the file list"
if ! diff -u <(listing "$PUB/hugo") <(listing "$PUB/ours") > /tmp/conform-files.diff 2>&1; then
  cat /tmp/conform-files.diff >&2
  fail "the theme publishes a different set of files than the scaffold."
fi

# 4. Skeleton. Same pages is not the same as the same page.
say "conform: comparing the page skeletons"
python3 scripts/skeleton.py "$PUB/hugo" > "$PUB/skeleton-hugo.json"
python3 scripts/skeleton.py "$PUB/ours" > "$PUB/skeleton-ours.json"
if ! diff -u "$PUB/skeleton-hugo.json" "$PUB/skeleton-ours.json" > "$PUB/skeleton.diff" 2>&1; then
  head -60 "$PUB/skeleton.diff" >&2
  fail "the theme renders a different page shape than the scaffold."
fi

say "conform: file list and skeleton agree"
