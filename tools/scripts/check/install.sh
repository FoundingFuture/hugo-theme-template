#!/usr/bin/env bash
# The gate the zip never had. Unzip the artefact into a site made with
# hugo new site. Write a config naming the theme and nothing else, and
# build it.
#
# A theme is never built. It is the source a site reads while that
# site is built. The only question is whether a site that adopted it
# still builds. The fixture cannot answer that. It is developed against
# this repository, and a downloader has a directory under themes/.
#
# Each component is then installed out of the fenced toml block in its
# own README, verbatim. The README is executed rather than paraphrased,
# so one that drifts from its component fails here.
# reads: dist features
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

command -v hugo >/dev/null 2>&1 || { echo "SKIP install: hugo not installed"; exit 3; }
# Git Bash has python and not python3, and unpacking a zip needs a
# reader either way. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"
command -v "$PY_BIN" >/dev/null 2>&1 || { echo "SKIP install: $PY_BIN not installed"; exit 3; }

slug="$(tools/scripts/slug.sh)"
tools/scripts/package.sh "$slug" >/dev/null || { echo "install:1: nothing to install."; exit 1; }
zip="$(find dist -maxdepth 1 -name "$slug-*.zip" -type f | head -1)"
[ -n "$zip" ] || { echo "install:1: no zip to unpack."; exit 1; }

work="$(mktemp -d tools/.install.XXXXXX)" || exit 1
trap 'rm -rf "$work"' EXIT

status=0
report() { printf '%s\n' "$1"; status=1; }

site="$work/site"
hugo new site "$site" --format toml >/dev/null 2>&1 || { echo "install:1: hugo new site failed."; exit 1; }
mkdir -p "$site/themes"
"$PY_BIN" tools/scripts/archive.py extract "$zip" "$site/themes"

mkdir -p "$site/content/posts" "$site/content/find"
cat > "$site/content/posts/one.md" <<'EOF'
+++
title = 'One'
date = 2026-01-01
tags = ['a']
+++

A paragraph with a [link](https://example.com/).

{{< youtube dQw4w9WgXcQ >}}

## A heading

Words enough to summarise.
EOF
printf '+++\ntitle = "Find"\nlayout = "search"\n+++\n' > "$site/content/find/index.md"

config() {
  printf "baseURL = 'https://example.org/'\nlocale = 'en-US'\ntitle = 'A Downloader'\ntheme = '%s'\n" "$slug"
}

# The first fenced toml block in a README, which is how a component
# says to install itself. THEME is the directory the theme went into.
instructions() {
  awk '
    /^```toml$/ { if (!found) { found = 1; inside = 1; next } }
    /^```$/     { inside = 0 }
    inside      { print }
  ' "$1" | sed "s|THEME|$slug|g"
}

build() {
  local label
  local out
  local code
  label="$1"
  out="$( cd "$site" && hugo --gc --destination "public-$label" \
            --panicOnWarning --printPathWarnings --printI18nWarnings \
            --logLevel warn 2>&1 )"
  code=$?
  if [ "$code" -ne 0 ]; then
    report "install:1: a site that installed the zip does not build ($label)."
    printf '%s\n' "$out" | grep -i "error\|warn" | head -3
    return 1
  fi
  return 0
}

holds() {
  local file
  file="$site/public-$1/$2"
  if [ ! -f "$file" ]; then
    report "install:1: $1, $2 is missing. The instructions do not work."
  elif ! grep -q "$3" "$file"; then
    report "install:1: $1, $2 does not carry $3."
  fi
}

# 1. The theme alone. Nothing mounted, nothing configured.
config > "$site/hugo.toml"
if build plain; then
  [ -f "$site/public-plain/posts/one/index.html" ] || \
    report "install:1: the page a site wrote is not published."

  # Every link on the page a site got without asking for one. A theme
  # that ships a menu decides navigation for somebody else's content.
  # Hugo drops an entry whose page is missing, rather than saying so.
  # What survives is a link to whatever they happen to have.
  while IFS= read -r href; do
    case "$href" in
      http*|"#"*|mailto:*|"") continue ;;
    esac
    for candidate in \
        "$site/public-plain${href}" \
        "$site/public-plain${href}index.html" \
        "$site/public-plain${href%/}/index.html"; do
      [ -f "$candidate" ] && continue 2
    done
    report "install:1: the theme links to $href, and nothing publishes it."
  done < <(grep -o 'href="[^"]*"' "$site/public-plain/index.html" | cut -d'"' -f2 | sort -u)
fi

# 2. One build per component, configured out of its own README. Two
#    components both writing [module] cannot share one config file, and
#    separately is how a site adopts them anyway.
for component in features/*/; do
  component="${component%/}"
  label="$(basename "$component")"
  [ -f "$component/README.md" ] || continue
  block="$(instructions "$component/README.md")"
  [ -n "$block" ] || {
    report "$component/README.md:1: no toml block. A component says how it is installed."
    continue
  }
  { config; printf '\n%s\n' "$block"; } > "$site/hugo.toml"
  build "$label" || continue
  case "$label" in
    search)
      holds "$label" find/index.html "search-form"
      holds "$label" index.json '"title"'
      size="$(wc -c < "$site/public-$label/index.json" 2>/dev/null || echo 0)"
      [ "$size" -le 1572864 ] || report "install:1: the index is $((size / 1024)) KB, over the limit it claims."
      ;;
    privacy-embeds)
      holds "$label" posts/one/index.html "embed-youtube"
      grep -q "<iframe" "$site/public-$label/posts/one/index.html" 2>/dev/null && \
        report "install:1: $label is mounted and an iframe still reaches another host."
      ;;
  esac
done

[ "$status" -eq 0 ] && printf '%s\n' "install: a bare site built on the zip, and every component out of its README"
exit $status
