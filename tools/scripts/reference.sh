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

# A no-op for every shortcode the theme defines and Hugo does not ship.
# Without one the fixture could only call Hugo's own, and a theme's
# additions went untested. The stub renders nothing, so the reference
# puts nothing where the theme puts something, which is the difference
# the comparison exists to measure.
stubs=tools/conformance/stubs.txt
if [ -f "$stubs" ]; then
  mkdir -p "$dest/hugo/layouts/_shortcodes"
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    name="${line%% *}"
    kind="${line#"$name"}"
    kind="${kind# }"
    # Hugo decides whether a shortcode may be closed by reading its
    # template for .Inner, not by running it. A paired one has to name
    # it and an unpaired one must not, so the two get different stubs.
    if [ "$kind" = paired ]; then
      printf '%s\n' '{{ if false }}{{ .Inner }}{{ end }}' \
        > "$dest/hugo/layouts/_shortcodes/$name.html"
    else
      : > "$dest/hugo/layouts/_shortcodes/$name.html"
    fi
  done < "$stubs"
fi
