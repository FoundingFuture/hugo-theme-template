+++
title = 'Page without a date'
description = 'A page carrying no date, so a theme that formats a dateline without checking for one renders an empty or zero value.'
+++

<!-- web-content:ignore-file -->

This page exercises a missing date. A dateline that assumes a date
renders the zero time here, which reads as the year one.

<!--more-->

## Expected handling

A theme guards the dateline with a check for a date.
