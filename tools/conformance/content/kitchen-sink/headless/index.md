+++
title = 'Headless bundle'
date = 2026-01-07T08:00:00Z
description = 'A headless bundle, which is never rendered and never listed, whose resources a template may still reach for.'
[build]
  render = 'never'
  list = 'never'
+++

This page exercises a headless bundle. Hugo publishes no page for it and
puts it in no list.

<!--more-->

## Reachability

A template can still read the resources of a headless bundle. Nothing
under this path appears in the built output.
