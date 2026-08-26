#!/usr/bin/env bash
# The theme installs as a module, by its repository path.
#
# The mounts prove the templates. They do not prove the path a user
# takes, which is hugo mod get. This builds a throwaway site that
# imports the theme and asks Hugo to resolve it.
#
# Running the verb in the fixture, which imports nothing, reported
# success without testing anything.
# reads: theme.toml
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

command -v go >/dev/null 2>&1 || { echo "SKIP module: go not installed"; exit 3; }

path="$(sed -n 's|^ *homepage *= *"https://github.com/\([^"]*\)".*|github.com/\1|p' theme.toml | head -1)"
[ -n "$path" ] || { echo "theme.toml:1: no homepage, so the module path is unknown."; exit 1; }

work=.module-check
rm -rf "$work"
mkdir -p "$work"
here="$(pwd -P)"
status=0
(
  cd "$work"
  cat > hugo.toml <<CONFIG
baseURL = "https://example.org/"
title = "Module check"
[module]
  [[module.imports]]
    path = "${path}"
  [[module.replacements]]
CONFIG
  # Resolved from the working tree, so the check does not need the tag
  # to be pushed before it can pass.
  printf 'replacements = "%s -> %s"\n' "$path" "$here" >> hugo.toml
  hugo mod init example.org/module-check >/dev/null 2>&1 || true
  hugo mod graph >/dev/null 2>&1
) || status=1

if [ "$status" -ne 0 ]; then
  echo "theme.toml:1: the theme does not resolve as a module at $path."
fi
rm -rf "$work"
exit $status
