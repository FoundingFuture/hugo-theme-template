+++
title = 'Built-in shortcodes'
date = 2026-01-22T08:00:00Z
description = 'A page calling the shortcodes Hugo ships, so a theme that overrides any of them can be measured against the original.'
+++

This page exercises the shortcodes Hugo ships. A theme may override any
of them, and the skeleton records what changes.

<!--more-->

## Figure

{{< figure src="/kitchen-sink/bundle/a.png" alt="A grey square shown through the figure shortcode" caption="A caption" >}}

## Parameter

The section colour cascaded from the parent: {{< param section_colour >}}

## Details

{{< details summary="A collapsed block" >}}
The body of the details element.
{{< /details >}}

## Quick reference

{{< qr text="https://example.org/" alt="A QR code linking to the example site" />}}

## Embeds

Hugo ships `youtube` and `vimeo`, and each renders an iframe from
another host, which the external gate forbids.

The `privacy-embeds` component overrides both with a poster and a link.
The page loads nothing from elsewhere, and the reader chooses whether to
leave.

{{< youtube id="dQw4w9WgXcQ" >}}

{{< vimeo id="55073825" >}}

Hugo also ships `x`. The component leaves it alone, and the fixture
never calls it.

Hugo's implementation fetches from `publish.x.com` while the site is
built. The build then depends on a third party being reachable and
willing, and a reference build cannot rest on that.

A site that does not mount the component gets Hugo's own renderings
back. The shortcode names in the content stay portable either way.
