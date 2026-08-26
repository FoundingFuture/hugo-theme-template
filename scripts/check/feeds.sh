#!/usr/bin/env bash
# The feeds and the sitemap are well formed, and they agree with what
# was published.
# reads: conformance/public/ours
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. scripts/python.sh answers both questions.
PY_BIN="$(scripts/python.sh 2>/dev/null || echo python3)"


target=conformance/public/ours
[ -d "$target" ] || { echo "SKIP feeds: no build at $target"; exit 3; }
# xmllint proves the XML parses. What matters more is whether the feeds
# and the sitemap agree with what was published. That needs no schema,
# so a missing xmllint does not skip the gate.
status=0
have_xmllint=no
command -v xmllint >/dev/null 2>&1 && have_xmllint=yes
[ "$have_xmllint" = no ] && printf '%s\n' "feeds: xmllint absent, checking agreement only"
if [ "$have_xmllint" = yes ]; then
  while IFS= read -r feed; do
    xmllint --noout "$feed" || { printf '%s\n' "$feed:1: not well formed."; status=1; }
  done < <(find "$target" -name 'index.xml')
  if [ -f "$target/sitemap.xml" ]; then
    xmllint --noout "$target/sitemap.xml" || {
      printf '%s\n' "$target/sitemap.xml:1: not well formed."; status=1; }
  fi
fi
"$PY_BIN" scripts/check/feeds.py "$target" || status=1
exit $status
