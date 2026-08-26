+++
title = 'Front matter keys'
date = 2026-01-08T08:00:00Z
lastmod = 2026-02-01T08:00:00Z
description = 'A page setting weight, slug, aliases, lastmod, images and a menu entry, so that each key can be observed in the output.'
weight = 20
slug = 'front-matter-keys'
aliases = ['/kitchen-sink/old-front-matter/']
images = ['a.png']
[menus.main]
  weight = 40
[params]
  custom = 'a value the theme may read'
+++

This page exercises the front matter keys a theme reads. Each key below
changes something observable in the built output.

<!--more-->

## Keys in use

The slug renames the published path. The alias publishes a redirect at
the old one. The menu entry adds a row to the main menu.

## Custom values

A custom key belongs under `params`, where Hugo reserves nothing. A key at
the top level would collide with a future Hugo release.
