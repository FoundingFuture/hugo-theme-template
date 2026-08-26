+++
title = 'reading-time'
date = 2026-01-25T08:00:00Z
description = 'The fixture page for the reading-time feature, kept short so that the reading time is one minute and the singular shows.'
[params]
  expect = ['1 minute read']
  reject = ['1 minutes read']
[params.features]
  reading-time = true
+++

This page exercises the reading-time feature. It is deliberately short,
so the reading time is one minute and the singular form is the one that
renders.

<!--more-->

## Off state

A page setting the same switch to false shows no reading time. The
comparison build turns every feature off and matches the scaffold.
