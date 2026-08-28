+++
title = 'Goldmark extensions'
date = 2026-01-21T08:00:00Z
description = 'A page holding every Goldmark extension the conformance config enables, from tables and footnotes to passthrough maths.'
+++

This page exercises the Goldmark extensions. Each block below needs its
own configuration, and a theme needs styling for each one.

<!--more-->

## Table

| Column | Meaning |
|---|---|
| one | the first |
| two | the second |

## Definition list

Term
: The definition of the term.

## Task list

- [x] A finished item
- [ ] An unfinished item

## Strikethrough and footnote

A ~~struck~~ word, and a footnote reference.[^1]

[^1]: The footnote body.

## Alert

> [!NOTE]
> An alert block, which Goldmark renders from a blockquote.

## Heading with an identifier {#custom-id}

The heading above carries an identifier written by hand.

## Mathematics

An inline expression, \(a^2 + b^2 = c^2\), inside a sentence.

$$
\int_0^1 x^2 \, dx = \frac{1}{3}
$$

## Emoji

An emoji written as a shortcode: :smile:
