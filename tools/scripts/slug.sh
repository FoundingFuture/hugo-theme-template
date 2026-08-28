#!/usr/bin/env bash
# The slug: the directory name a downloader unzips the theme into.
# It is also the name a site writes in the theme key.
#
# theme.toml's homepage is where bootstrap recorded the repository. A
# theme is installed under the name of the repository it came from. A
# checkout directory somebody renamed carries a different name.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

# A trailing slash is ordinary in a URL, and the pattern that read the
# last path segment directly returned nothing for one. The slug then
# fell back to the checkout's directory name, which is not the theme's
# name and is whatever somebody cloned into.
slug=""
if [ -f theme.toml ]; then
  home="$(sed -n 's|^ *homepage *= *"\{0,1\}\([^"]*\)"\{0,1\} *$|\1|p' theme.toml | head -1)"
  home="${home%/}"
  slug="${home##*/}"
fi
[ -n "$slug" ] || slug="$(basename "$PWD")"
printf '%s\n' "$slug"
