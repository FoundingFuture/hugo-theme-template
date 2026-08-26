# Changelog

## Unreleased

First working pipeline. `./c init` generates a theme and `./c check`
passes on it with no finding.

- Fifteen checks across four gates, each a script that runs alone.
- A fixture of thirty-six pages, one per Hugo feature.
- Twelve features ship installed, seven on and five off.
- A feature declares what it renders, and the build holds it to that.
- An outbound link carries rel with external and noopener, and a gate
  reads it. A link stays visibly different from a subresource.
- The scale build time lands in the pull request report on every run.
- `./c site=` builds any real Hugo site against the theme.
- Two components: `privacy-embeds` and `search`.
- A tracked file over a megabyte fails, and a directory no check reads
  fails.
