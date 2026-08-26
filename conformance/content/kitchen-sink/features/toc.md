+++
title = 'toc'
date = 2026-01-25T08:00:00Z
description = 'The fixture page for the toc feature, which turns the switch on so that what the manifest declares can be seen.'
[params.features]
  toc = true
+++

This page exercises the toc feature. The switch above turns it on,
so the element its manifest declares appears on the page.

## Off state

A page setting the same switch to false carries none of it. The
comparison build turns every feature off and has to match the reference
scaffold exactly.
