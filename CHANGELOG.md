# Changelog

## Unreleased

- A third component, katex. Its passthrough render hook hands every
  formula to the KaTeX inside Hugo at build time. MathML is the
  default output. It needs no stylesheet. Setting `params.katex.output`
  to `htmlAndMathml` adds the KaTeX markup. The component then links
  its own copy of the KaTeX 0.16.21 stylesheet and woff2 fonts. Only a
  page that carries a formula gets the link. Nothing reaches another
  host.
- The fixture uses the math delimiters the Hugo documentation names,
  `\(` `\)` inline and `$$` or `\[` `\]` for a display formula. The
  single dollar sign is gone, so a price in prose stays a price.
- The page skeleton skips a subtree marked `aria-hidden`. A reader
  using assistive technology never meets one. KaTeX puts a class on
  every box of the markup it hides that way.
- `build/install` builds the `katex` component out of its README and
  checks that a formula reaches the page as a `math` element.

## v0.1.0, 2026-08-29

A generated theme is now installable and listable. The example site and
the module path are new, and a theme's data and parameters moved.

- `./c init` generates `exampleSite/`, which themes.gohugo.io reads and
  a reviewer opens first. Hugo writes the site, and the scaffold's own
  content fills it. `build/example` builds it the way a downloader
  does, from the artefact unzipped into `themes/<slug>`.
- `go.mod` arrives with it, so `hugo mod get` resolves the theme.
  `release/module` reads the path from there, rather than inferring it
  from whatever `theme.toml` names as the homepage.
- The manifests move to `data/<slug>/features`, and the parameters to
  `params.<slug>`. Hugo merges a theme's data into the site's and the
  site wins, so an unnamespaced theme is one a site overrides by
  accident. `static/namespace` holds the generated name to `slug.sh`.
- A theme may define its own shortcodes. The reference build reads
  `tools/conformance/stubs.txt` and renders a no-op for each name, so
  the comparison measures what the theme adds where the scaffold puts
  nothing.
- `slot.html` indexes the manifests once for the site, and caches each
  page's feature states. It walked all fourteen on every slot call.
- The content linter is gone. A theme repository holds templates and no
  content, so there was nothing here for it to grade.
- Two gates that had never once passed. `release/module` wrote a
  `module.replacements` table where Hugo reads a list of strings, and
  `slug.sh` answered with the checkout's directory name whenever the
  homepage ended in a slash.

## v0.0.2, 2026-08-28

- Git tracks nothing a tool writes. A `.pyc`, a `__pycache__` or a
  `node_modules` anywhere in the tree now fails the coverage check.

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
