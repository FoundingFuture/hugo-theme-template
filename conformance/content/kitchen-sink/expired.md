+++
title = 'Expired page'
date = 2020-01-01T08:00:00Z
expiryDate = 2021-01-01T08:00:00Z
description = 'A page whose expiry date has passed, which must not appear in the built output or in any list of pages.'
+++

This page exercises an expiry date in the past. Hugo leaves it out of a
normal build.

<!--more-->

## Expected handling

No file is written for this page. No list names it.
