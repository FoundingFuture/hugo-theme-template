# hugo-theme-template

A GitHub template that produces a Hugo theme project. The template holds
no theme. The first command generates one from whichever Hugo version
is installed that day. A project never starts from a scaffold frozen when
the template was written.

What the template carries is the pipeline.

## Starting a project

Press "Use this template" on GitHub and name the repository. The name
is the theme's name, in any form. Hugo gets a slug derived from it, so
`My Theme` is `my-theme` in `theme.toml` and in the module path.

The button copies the files and makes one commit. That commit is a push
to `main`, which brings up `bootstrap.yml`, which runs `./c init` and
commits the theme. A minute later the repository holds:

- a theme generated from the newest Hugo release, in a second commit
- `theme.toml` with the owner and repository filled in
- a history of two commits, none of them the template's
- Actions running `check.yml` on every push from now on

Then, on your machine:

```sh
git clone git@github.com:<owner>/<repository>.git
cd <repository>
./c setup
./c check
```

The last command passes on a fresh scaffold. From then on every change
is measured against that baseline. `./c init` deletes the marker file
and the workflow, so the workflow never runs again.

## Cloning instead

A clone of the template can run `./c init` by hand. The theme comes out
the same. Three things the button provides do not:

- The history is the template's. Every commit in it is about the
  pipeline, not the theme.
- The remote is the template. A push goes to the wrong repository, or
  is refused.
- There is no repository on GitHub, so nothing runs `check.yml`.

`./c init` sees the template in the remote and reads no owner from it.
Given the project's owner and repository, it also cuts the clone loose:

```sh
git clone git@github.com:FoundingFuture/hugo-theme-template.git my-theme
cd my-theme
./c init name="My Theme" owner=<owner> repo=my-theme
git add -A && git commit -m "Generate theme scaffold from Hugo $(cat .hugo-version)"
gh repo create <owner>/my-theme --public --source=. --push
```

After `init` the remote is gone and the branch has no commits. The
commit that follows is the root of the project's history. The closing
message prints these commands, a `git push` alternative for those
without `gh`, and the two lines that undo the cut.

Without `owner=` and `repo=`, `init` leaves the history and the remote
as they are, keeps the placeholder in `theme.toml`, and prints the
three commands that do the same by hand.

## The command

Every action goes through `./c`, locally and in CI, so a green run here
predicts a green run there. Bare `./c` runs every gate and, on green,
names the deliverable: `dist/<slug>-<version>.zip`, the theme called
what the repository is called. Run `./c help` for the table.

```sh
./c                  every gate, then the deliverable in dist/
./c package          write dist/<slug>/ and the zip a downloader gets
./c conform          build against the scaffold and against the theme, then diff
./c check            every gate in order, stopping at the first failure
./c check gate=static   one gate
./c serve            the fixture site, reading the sources, with live reload
```

`./c` is the only thing at the root that is not the theme. Everything it
runs lives under `tools/`. The gate scripts, the fixture site, the
feature catalogue, and the configuration each linter reads. A project's
root is its own theme and one command, so the theme reads as a theme.

## What conformance means

A fixture site builds twice. Once against the scaffold of the installed
Hugo, once against the theme under development. Both are read the same
way, as a theme directory. The scaffold as `hugo new theme` wrote it,
this theme as `./c package` wrote it. Two things are compared.

The file list, so the theme publishes the same pages, feeds, aliases
and sitemap entries. Then the skeleton of every page. That is the
heading outline, the links and images inside the content, and the
counts of the block elements. Every classed element is recorded with the
text it carries.

Markup and styling are free to differ. What a reader can find on the
page has to match.

The reference is regenerated before every run, so it always matches the
Hugo doing the building.

## What the gates need

Only Hugo is needed to build. Each gate names its own tool, and a gate
whose tool is absent prints `SKIP`. That is a warning on a workstation
and a failure under CI, where every tool is present. The release path
runs there, so nothing partly checked is ever published.

Three things are yours to install: Git, Hugo extended and Python 3.
On Windows that means Git for Windows, whose Git Bash runs `./c`.
`./c setup` reports everything else, then fetches what it can:

```sh
./c setup            the report, then the light tier into the tree
./c setup full       the browser tier too, Chromium included
./c setup report     only look
```

A pinned ShellCheck, htmltest and the newest Hugo land in
`tools/.deps/bin`. The npm tools land in `tools/node_modules`, and
html5validator in the shared venv. Node, Go and a Java runtime come
through the machine's package manager when one is present. That is
brew, apt, dnf, pacman or winget. Where no manager or no mapping
helps, setup prints the command or the link and leaves it to you.

| Tool | Used by | How it arrives |
|---|---|---|
| [Hugo](https://gohugo.io/installation/), extended | everything | yours to install, and the only hard requirement |
| [Python 3](https://www.python.org/downloads/) | most checks | yours to install, 3.9 or later |
| [Git](https://git-scm.com/downloads) | everything, and Git Bash runs `./c` on Windows | yours to install |
| [Node.js](https://nodejs.org/) | runs the five npm tools | the package manager, by `./c setup` |
| [Go](https://go.dev/dl/) | `release/module` | the package manager, by `./c setup` |
| [ShellCheck](https://www.shellcheck.net/) | `static/shellcheck` | pinned, fetched by `./c setup` |
| [htmltest](https://github.com/wjdp/htmltest) | `output/validity`, `output/nojs` | pinned, fetched by `./c setup` |
| newest Hugo, as `hugo-latest` | `build/versions` | fetched by `./c setup` |
| [writing-lint](https://github.com/FoundingFuture/writing-lint) | `static/comments` | fetched by tag, on its first ask |
| [Stylelint](https://stylelint.io/) | `static/css` | npm, by `./c setup` |
| [ESLint](https://eslint.org/) | `static/js` | npm, by `./c setup` |
| [html5validator](https://github.com/svenkreiss/html5validator) | `output/validity` | `./c setup full`, and it drives Java |
| [pa11y-ci](https://pa11y.org/) | `output/a11y` | `./c setup full`, and it drives a browser |
| [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci) | `output/perf` | `./c setup full`, and it drives a browser |
| [Playwright](https://playwright.dev/) | `output/visual` | `./c setup full`, Chromium included |

Two of them drive a browser. Playwright installs one, and the perf gate
finds it. A system Chrome or Chromium works as well.

`./c help check` lists every gate and the script behind it.

### Checking the template itself

The template carries no theme, so most gates have nothing to read.
`./c check` in it runs the `template` gate, the subset needing no theme:
coverage, portability, ShellCheck and the comment rules.

Without it the template's own README and changelog were read by nothing.
Bootstrap replaces both, so no generated project ever sees them.

## The gates

| Gate | What it reads |
|---|---|
| static | the sources, with no build |
| build | the artefact, a site that installed it, four builds and the scale fixture |
| output | the built pages |
| release | the tag, the changelog and the module path |

### What the scale gate is for

A template running a site-wide query in a per-page loop is fast on
twenty pages and slow on two thousand. The scale fixture builds two
thousand posts, so the cost has somewhere to show.

It found one on its first honest run, in this template's own pager
feature. The partial filtered `site.RegularPages` on every page render.
Hugo keeps the neighbours of a page in its section, so `PrevInSection`
answers without a search.

| | before | after |
|---|---|---|
| template time | 75.7 s | 11.3 s |
| scale build | 8 s | 2 s |

The gate weighs cost against cache potential. It does not fail on
potential alone.

A partial reporting a reading time returns the same words whenever two
pages read alike. Caching that by page would be a correctness bug
wearing the clothes of an optimisation.

## Features

A feature is an optional element the theme renders, registered to a slot
and switched by one line. `./c feature list` shows them.

Fourteen ship installed: twelve toggles and two components. Nine are on
and five are off, and one line in the config moves any of them. A
feature is never edited out of a template.

```sh
./c feature list          every feature, installed or available
./c feature add name=x    install one the template ships
./c feature new name=x    start one of your own
./c feature off name=x    write the switch into the fixture config
```

`./c feature add` is the path for anything beyond the starter set. The
catalogue it copies from stays in `tools/templates/feature/`, so a feature removed from a
project can be put back.

### Two levels

A **toggle** is a partial in the theme, wired to a slot and switched by
one line. Most features are toggles.

A **component** is a directory under `features/` with its own layouts,
assets and words, mounted beside the theme. Turning one off means not
mounting it, which is what makes it a component rather than a toggle.

`privacy-embeds` overrides Hugo's `youtube` and `vimeo` with a poster
and a link. A page then loads nothing from another host until the reader
follows it. A site without the component gets Hugo's own renderings
back, so the shortcode names in the content stay portable.

`search` publishes a JSON index and a search page. The page lists every
page in its own markup. A reader with the script blocked then has a
working index rather than an empty box. The script filters that list and
fetches nothing. The index is held under 1.5 MB by a gate.

Two components ship, and two is the point. `search` proves the level
that mounts a directory, and `features/<name>/README.md` says how a
second one is written. A component whose only real page lives in a
site is better written there, against that page. A fixture page invented
for it would be designing the thing twice. The mechanism is proven
either way.

A manifest declares what the feature adds to the rendered page. The
fixture builds three times. The reference scaffold, the theme with every
feature off, and the theme with them at their defaults.

With the features off the theme has to match the scaffold exactly. With
them on, the only differences allowed are the ones the manifests
declared.

A manifest names the container its links and headings sit in. It names
the classed elements it adds, and the elements it adds more of. A
feature changing anything else fails the build.

The h1 is nobody's to add. The reference and the theme are compared on
the h1 of every page, by itself. The claim cannot go quiet.

Nothing is kept in an ignore list. That is the point. An ignore list
goes stale, and a declaration stays true because the build reads it.
