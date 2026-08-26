#!/usr/bin/env bash
# Generate the reference theme: whatever "hugo new theme" writes today.
#
# The directory is gitignored and rebuilt before every use, so the
# reference always matches the Hugo doing the building. A stale reference
# would be worse than none.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

dest=tools/conformance/themes
rm -rf "$dest/hugo"
mkdir -p "$dest"
hugo new theme hugo --themesDir "$dest" >/dev/null

# The fixture supplies content and config. A theme that carries its own
# would win over the fixture's and the two builds would not compare.
rm -rf "$dest/hugo/content" "$dest/hugo/hugo.toml"
