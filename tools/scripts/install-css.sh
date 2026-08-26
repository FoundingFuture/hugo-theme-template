#!/usr/bin/env bash
# Build the stylesheet from the theme's own plus every enabled feature.
#
# A feature shipped a stylesheet that reached nothing. main.css imports
# the components and knows nothing of features. The rules for a reading
# time were built into the theme and never served.
#
# A feature switched off contributes no bytes, which is what makes a
# switch worth having.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

partials=layouts/_partials
[ -d "$partials" ] || partials=layouts/partials
target="$partials/head/css.html"
[ -f "$target" ] || exit 0
grep -q 'features' "$target" && exit 0

cat > "$target" <<'HOOK'
{{- /* The theme's own stylesheet, then one per enabled feature, joined
       into a single file. A feature that is off adds nothing.

       The switch is read from the site, not from a page. A stylesheet
       is served to the whole site, so a per-page override cannot change
       which rules it carries. */ -}}
{{- $sheets := slice }}
{{- with resources.Get "css/main.css" }}
  {{- $sheets = $sheets | append . }}
{{- end }}
{{- /* The code colours, which the theme owns rather than inherits as
       inline styles it cannot override. */ -}}
{{- with resources.Get "css/chroma.css" }}
  {{- $sheets = $sheets | append . }}
{{- end }}
{{- /* The rules that keep a link visible and reachable. */ -}}
{{- with resources.Get "css/a11y.css" }}
  {{- $sheets = $sheets | append . }}
{{- end }}
{{- $features := slice }}
{{- range $name, $manifest := hugo.Data.features }}
  {{- $on := $manifest.default }}
  {{- with site.Params.features }}
    {{- $found := index . $name }}
    {{- if ne $found nil }}{{ $on = $found }}{{ end }}
  {{- end }}
  {{- if and $on $manifest.css }}
    {{- $features = $features | append (dict
          "weight" (default 50 $manifest.weight) "css" $manifest.css) }}
  {{- end }}
{{- end }}
{{- range sort $features "weight" }}
  {{- with resources.Get .css }}
    {{- $sheets = $sheets | append . }}
  {{- end }}
{{- end }}
{{- with $sheets }}
  {{- $opts := dict
    "minify" (cond hugo.IsDevelopment false true)
    "sourceMap" (cond hugo.IsDevelopment "linked" "none")
  }}
  {{- with . | resources.Concat "css/bundle.css" | css.Build $opts }}
    {{- if hugo.IsDevelopment }}
      <link rel="stylesheet" href="{{ .RelPermalink }}">
    {{- else }}
      {{- with . | fingerprint }}
        <link rel="stylesheet" href="{{ .RelPermalink }}" integrity="{{ .Data.Integrity }}" crossorigin="anonymous">
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
HOOK
