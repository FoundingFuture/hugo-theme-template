#!/usr/bin/env bash
# Assemble the theme a downloader gets. Everything at the root that is
# the theme, and nothing that checks it.
#
# The list lives here and nowhere else. The release workflow builds the
# zip from it, and a gate builds a site against it. A name that moves is
# then caught on the run that moves it, rather than on release day.
# reads: theme.toml
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

dest="${1:?usage: package.sh DEST [NAME]}"
name="${2:-$(basename "$PWD")}"

rm -rf "${dest:?}/$name"
mkdir -p "$dest/$name"

# The glob passes over dotfiles, which is the answer we want. A theme
# carries no .github, no .gitignore and no .hugo-version. Those belong
# to the project that develops it.
for entry in *; do
  case "$entry" in
    tools|c) continue ;;
  esac
  cp -R "$entry" "$dest/$name/"
done

printf '%s\n' "$dest/$name"
