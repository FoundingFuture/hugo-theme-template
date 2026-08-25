# Changelog

## Unreleased

First working pipeline. `./c init` generates a theme and `./c check`
passes on it with no finding.

- Fifteen checks across four gates, each a script that runs alone.
- A fixture of thirty-six pages, one per Hugo feature.
- A feature declares what it renders, and the build holds it to that.
- `./c site=` builds any real Hugo site against the theme.
