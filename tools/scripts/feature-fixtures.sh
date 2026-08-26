#!/usr/bin/env bash
# Write one fixture page per installed feature.
#
# Each page turns its own feature on in front matter and names the
# element the manifest declares. The comparison build turns it off.
#
# The static gate stops a feature with no fixture page. This runs at
# bootstrap, and again whenever a feature is installed.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

dest=tools/conformance/content/kitchen-sink/features
mkdir -p "$dest"

cat > "$dest/_index.md" <<'PAGE'
+++
title = 'Features'
date = 2026-01-24T08:00:00Z
description = 'One page per shipped feature, each turning its own feature on so that what the manifest declares can be seen.'
+++

Every page below exercises one feature. The switch in its front matter
turns that feature on, and the sibling section turns it off.
PAGE

for manifest in data/features/*.toml; do
  [ -e "$manifest" ] || continue
  name="$(basename "$manifest" .toml)"
  [ -e "$dest/$name.md" ] && continue
  # A feature may ship a fixture page of its own. The generated one
  # cannot say what that feature has to render.
  if [ -f "tools/templates/feature/pages/$name.md" ]; then
    cp "tools/templates/feature/pages/$name.md" "$dest/$name.md"
  else
    sed -e "s|{{NAME}}|$name|g" tools/templates/feature/page.md.tmpl > "$dest/$name.md"
  fi
done
