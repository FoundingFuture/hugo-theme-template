#!/usr/bin/env bash
# The theme as a downloader gets it. Assemble the zip, drop it under
# themes/ in a site that has nothing else, and build that site.
#
# A theme is never built. It is the source a site reads while the site
# is built. The only question worth asking is whether a site that
# adopted it still builds.
#
# The fixture mounts this repository as the theme. A component's
# directory is then wherever the fixture's own config says it is. A
# downloaded copy sits under themes/, and only a real install tells the
# two apart.
#
# A component is then installed the way its own README says to install
# it. The configuration is read out of that README, not written here.
# Instructions that stop working fail the build that broke them.
# reads: theme.toml layouts assets i18n data features
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

command -v hugo >/dev/null 2>&1 || { echo "SKIP package: hugo not installed"; exit 3; }

work="$(mktemp -d tools/.package.XXXXXX)" || exit 1
trap 'rm -rf "$work"' EXIT

name=theme-under-test
mkdir -p "$work/themes" "$work/content/posts" "$work/content/find"
tools/scripts/package.sh "$work/themes" "$name" >/dev/null || {
  echo "package:1: could not assemble the theme."
  exit 1
}

cat > "$work/content/posts/one.md" <<'EOF'
+++
title = 'One'
date = 2026-01-01
tags = ['a']
+++

A paragraph with a [link](https://example.com/).

{{< youtube dQw4w9WgXcQ >}}

## A heading

More words.
EOF
printf '+++\ntitle = "Find"\nlayout = "search"\n+++\n' > "$work/content/find/index.md"

status=0

# The first fenced toml block in a README, which is how each component
# says to install itself.
instructions() {
  awk -v found=0 '
    /^```toml$/ { if (!found) { found = 1; inside = 1; next } }
    /^```$/     { inside = 0 }
    inside      { print }
  ' "$1" | sed "s|THEME|$name|g"
}

build() {
  local label
  local out
  local code
  label="$1"
  out="$( cd "$work" && hugo --gc --destination "public-$label" 2>&1 )"
  code=$?
  if [ "$code" -ne 0 ]; then
    printf '%s\n' "package:1: a site with the $label install does not build."
    printf '%s\n' "$out" | grep -i error | head -3
    status=1
    return 1
  fi
  return 0
}

config() {
  printf "baseURL = 'https://example.org/'\nlocale = 'en-US'\ntitle = 'A Downloader'\ntheme = '%s'\n" "$name"
}

holds() {
  local file
  local want
  local label
  label="$1"
  file="$work/public-$label/$2"
  want="$3"
  if [ ! -f "$file" ]; then
    printf '%s\n' "package:1: $label, $2 is missing. The instructions do not work."
    status=1
  elif ! grep -q "$want" "$file"; then
    printf '%s\n' "package:1: $label, $2 does not carry $want."
    status=1
  fi
}

# A plain install. Every component is unmounted, and a theme that needs
# one to render is a theme a downloader cannot use.
config > "$work/hugo.toml"
build plain

# One build per component, each configured out of its own README. Two
# components both writing [module] cannot share one config file, and
# separately is how a site adopts them anyway.
for component in features/*/; do
  component="${component%/}"
  label="$(basename "$component")"
  [ -f "$component/README.md" ] || continue
  block="$(instructions "$component/README.md")"
  [ -n "$block" ] || {
    printf '%s\n' "$component/README.md:1: no toml block. A component says how it is installed."
    status=1
    continue
  }
  { config; printf '\n%s\n' "$block"; } > "$work/hugo.toml"
  build "$label" || continue
  case "$label" in
    search)
      holds "$label" find/index.html "search-form"
      holds "$label" index.json '"title"'
      ;;
    privacy-embeds)
      holds "$label" posts/one/index.html "embed-youtube"
      if grep -q "<iframe" "$work/public-$label/posts/one/index.html" 2>/dev/null; then
        printf '%s\n' "package:1: $label is mounted and an iframe still reaches another host."
        status=1
      fi
      ;;
  esac
done

exit $status
