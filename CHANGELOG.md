# Changelog

## v0.0.1, 2026-08-28

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
- Two components: `privacy-embeds` and `search`. A third, tag
  narrowing, waits for the site that has the page it narrows.
- The artefact is the deliverable. `./c package` writes `dist/<slug>/`
  from the include list in `package.txt`, and everything consumes it:
  the fixture, the demo, the release and the install gate.
- `build/install` unzips it into a bare site and builds. A component
  is installed there out of the toml block in its own README.
- The zip is written and read by Python. zip and unzip are not needed,
  and Git for Windows ships neither. Sorted entries and a fixed stamp,
  so the same commit packs byte for byte the same anywhere.
- The theme carries no baseURL, no title and no menu. Hugo merges a
  theme's menus into every site that adopts it, and navigation is the
  site's to decide.
- A tracked file over a megabyte fails, and a directory no check reads
  fails.
- The fixture's content is test data. The pipeline reads its structure
  and never its prose, so the content check is gone.
- The feeds check parses with the standard library. xmllint left the
  table of what a theme author installs.
- `./c setup` reports what the machine has and fetches what it can. A
  pinned ShellCheck, htmltest and the newest Hugo land in the tree,
  and CI fetches through the same script.
- A deliverable that skipped checks says so as it is handed over.
