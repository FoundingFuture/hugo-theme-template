+++
title = 'Page without a description'
date = 2026-01-09T08:00:00Z
+++

<!-- web-content:ignore-file -->

This page exercises a missing description. A theme falls back to the
summary, and the first paragraph is long enough that the fallback has to
truncate it somewhere sensible rather than emitting the whole thing into
a meta tag where a search engine will cut it off mid word and show the
reader a ragged fragment instead of a sentence that ends.

<!--more-->

## Expected handling

The head partial falls back to a truncated summary.
