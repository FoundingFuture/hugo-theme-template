#!/usr/bin/env bash
# Move the scaffold's hardcoded English into i18n, once, at bootstrap.
#
# The rendered words do not change, so the skeleton diff against the
# reference stays empty. What changes is that a downloader can
# translate them. The words gate stops on a bare text node. A scaffold
# left as Hugo writes it would fail its own first check.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

partials=layouts/_partials
[ -d "$partials" ] || partials=layouts/partials
[ -d "$partials" ] || { echo "no partials directory" >&2; exit 1; }

footer="$partials/footer.html"
if [ -f "$footer" ] && grep -q 'All rights reserved' "$footer"; then
  cat > "$footer" <<'HTML'
<p>{{ i18n "copyright" (dict "Year" now.Year) }}</p>
HTML
fi

mkdir -p i18n
if [ ! -f i18n/en.toml ]; then
  cat > i18n/en.toml <<'TOML'
# Every string the templates render. A theme that spells a word inside
# its markup cannot be translated. The words gate reads the keys here
# to decide whether one is used or missing.

[copyright]
other = "Copyright {{ .Year }}. All rights reserved."
TOML
fi
