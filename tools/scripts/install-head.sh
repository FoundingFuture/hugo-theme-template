#!/usr/bin/env bash
# Give the generated head what every page owes a reader and a crawler.
#
# The Hugo scaffold writes a charset, a viewport and a title. It writes
# no description, no canonical and no Open Graph tags. A scaffold left
# alone therefore fails the head gate on its first run.
#
# None of this appears in the page skeleton, so the conformance diff
# against the reference stays empty.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

partials=layouts/_partials
[ -d "$partials" ] || partials=layouts/partials
head="$partials/head.html"
[ -f "$head" ] || { echo "no $head" >&2; exit 1; }
grep -q 'rel="canonical"' "$head" && exit 0

cat >> "$head" <<'HTML'
{{- /* A description, in order of preference: the page's own, then its
       summary trimmed to a length a search result will show, then the
       site title, so the tag is never empty. */ -}}
{{- $description := .Description }}
{{- if not $description }}{{ with .Summary }}{{ $description = . | plainify | chomp | truncate 155 }}{{ end }}{{ end }}
{{- if not $description }}{{ $description = site.Title }}{{ end }}
{{- $ogTitle := cond .IsHome site.Title .Title }}
<meta name="description" content="{{ $description }}">
<link rel="canonical" href="{{ .Permalink }}">
<meta property="og:title" content="{{ $ogTitle }}">
<meta property="og:description" content="{{ $description }}">
<meta property="og:type" content="{{ cond .IsPage "article" "website" }}">
<meta property="og:url" content="{{ .Permalink }}">
HTML

# The scaffold puts the site title in an h1 in the header. The page
# title goes in a second h1 below it. Two on one page leave a screen
# reader with no single heading. The site title stays an h1 on the home
# page, where it is the page's own title.
header="$partials/header.html"
if [ -f "$header" ] && ! grep -q 'IsHome' "$header"; then
  cat > "$header" <<'HTML'
{{ if .IsHome }}
  <h1>{{ site.Title }}</h1>
{{ else }}
  <p class="site-title"><a href="{{ site.Home.RelPermalink }}">{{ site.Title }}</a></p>
{{ end }}
{{ partial "menu.html" (dict "menuID" "main" "page" .) }}
HTML
fi
