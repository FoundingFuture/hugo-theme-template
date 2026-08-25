+++
title = 'Built-in shortcodes'
date = 2026-01-22T08:00:00Z
description = 'A page calling the shortcodes Hugo ships, so a theme that overrides any of them can be measured against the original.'
+++

This page exercises the shortcodes Hugo ships. A theme may override any
of them, and the skeleton records what changes.

## Figure

{{< figure src="/kitchen-sink/bundle/a.png" alt="A grey square shown through the figure shortcode" caption="A caption" >}}

## Parameter

The section colour cascaded from the parent: {{< param section_colour >}}

## Details

{{< details summary="A collapsed block" >}}
The body of the details element.
{{< /details >}}

## Quick reference

{{< qr text="https://example.org/" />}}
