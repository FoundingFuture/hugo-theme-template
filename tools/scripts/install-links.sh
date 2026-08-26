#!/usr/bin/env bash
# Give the generated theme a link render hook.
#
# A link leaving the site carries rel with external and noopener. The
# external gate reads those. The difference between a link a reader
# follows and a subresource the page fetches then stays visible in the
# output. It does not live in a rule alone.
#
# The href and the link text do not change. The page skeleton is the
# same, so the conformance diff stays empty.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

mkdir -p layouts/_markup
hook=layouts/_markup/render-link.html
[ -f "$hook" ] && exit 0

cat > "$hook" <<'HOOK'
{{- /* A link leaving the site says so, with rel external and noopener.

       Overriding this hook also takes over resolving the destination,
       which Hugo's own hook does. A relative path and a bare fragment
       both have to be resolved here, or every such link in the content
       would be published exactly as it was written. */ -}}
{{- $href := .Destination }}
{{- $parsed := urls.Parse .Destination }}
{{- $external := false }}
{{- with $parsed.Host }}
  {{- $external = ne . (urls.Parse site.BaseURL).Host }}
{{- end }}
{{- if not $external }}
  {{- if hasPrefix .Destination "#" }}
    {{- $href = printf "%s%s" .Page.RelPermalink .Destination }}
  {{- else if not $parsed.Scheme }}
    {{- with .Page.GetPage $parsed.Path }}
      {{- $href = .RelPermalink }}
      {{- with $parsed.Fragment }}
        {{- $href = printf "%s#%s" $href . }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
<a href="{{ $href | safeURL }}"
  {{- with .Title }} title="{{ . }}"{{ end }}
  {{- if $external }} rel="external noopener"{{ end }}>{{ .Text }}</a>
HOOK
