+++
title = 'katex'
date = 2026-01-25T08:00:00Z
description = 'The fixture page for the katex component, carrying an inline and a display formula in each delimiter the site enables.'
[params]
  # The rendered page carries the integral sign itself. The command that
  # names it survives too, inside the MathML annotation, so a reject
  # rule cannot name it.
  expect = ['∫', 'α']
[params.features]
  katex = true
+++

This page exercises the katex component. Each formula below is
rendered at build time by the KaTeX inside Hugo. The rendered page
carries the integral sign itself.

<!--more-->

## Inline

The energy of a photon is \(E = h \nu\), and the angle is \(\alpha\).

## Display, dollar delimiters

$$
\int_0^1 x^2 \, dx = \frac{1}{3}
$$

## Display, bracket delimiters

\[
e^{i\pi} + 1 = 0
\]

## Off state

The comparison build mounts no component, so the delimiters and the
commands pass through as written.
