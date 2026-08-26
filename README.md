# hugo-theme-template

A GitHub template that produces a Hugo theme project. The template holds
no theme. The first command generates one from whichever Hugo version
is installed that day. A project never starts from a scaffold frozen when
the template was written.

What the template carries is the pipeline.

## Starting a project

```sh
git clone git@github.com:FoundingFuture/hugo-theme-template.git my-theme
cd my-theme
./c init name=my-theme
git add -A && git commit -m "Generate theme scaffold from Hugo $(cat .hugo-version)"
./c check
```

The last command passes on a fresh scaffold. From then on every change
is measured against that baseline.

## Starting from the button

The GitHub "Use this template" button copies the files and makes an
initial commit. It runs no script of its own. That commit is a push to
`main`, which brings up `bootstrap.yml`, which runs `./c init` and
commits the theme.

So a repository made with the button arrives with its theme already
generated, and the sequence above is already done. `./c init` deletes
the marker file, so the workflow never triggers again. It also removes
itself, along with the other one-shot pieces.

Cloning the template and running `./c init` by hand gives the same
result.

## The command

Every action goes through `./c`, locally and in CI, so a green run here
predicts a green run there. Run `./c help` for the table.

```sh
./c conform          build against the scaffold and against the theme, then diff
./c check            every gate in order, stopping at the first failure
./c check gate=static   one gate
./c serve            the fixture site with live reload
```

## What conformance means

A fixture site builds twice. Once against the scaffold of the installed
Hugo, once against the theme under development. Two things are compared.

The file list, so the theme publishes the same pages, feeds, aliases
and sitemap entries. Then the skeleton of every page. That is the
heading outline, the links and images inside the content, and the
counts of the block elements. Every classed element is recorded with the
text it carries.

Markup and styling are free to differ. What a reader can find on the
page is not.

The reference is regenerated before every run, so it always matches the
Hugo doing the building.

## What the gates need

Only Hugo is needed to build. Each gate names its own tool, and a gate
whose tool is absent prints `SKIP`. That is a warning on a workstation
and a failure under CI, where the image carries all of them.

Install what you want to run. Nothing here is bundled, because the way
to install it differs by platform.

| Tool | Used by | Where |
|---|---|---|
| [Hugo](https://gohugo.io/installation/), extended | everything | required, and the only one that is |
| [Python 3](https://www.python.org/downloads/) | most checks | 3.9 or later |
| [Go](https://go.dev/dl/) | `release/module` | resolves the theme as a module |
| [Node.js](https://nodejs.org/) | runs the five tools below | 20 or later |
| [ShellCheck](https://www.shellcheck.net/) | `static/shellcheck` | every script in the repository |
| [Stylelint](https://stylelint.io/) | `static/css` | with `stylelint-config-standard` |
| [ESLint](https://eslint.org/) | `static/js` | only when the theme has a script |
| [writing-lint](https://github.com/FoundingFuture/writing-lint) | `static/comments`, `output/content` | fetched by tag into `.tools/` |
| [html5validator](https://github.com/svenkreiss/html5validator) | `output/validity` | the Nu validator, so it needs Java |
| [htmltest](https://github.com/wjdp/htmltest) | `output/validity`, `output/nojs` | every link resolves |
| [pa11y-ci](https://pa11y.org/) | `output/a11y` | WCAG 2.1 AA, and it drives a browser |
| [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci) | `output/perf` | budgets, and it drives a browser |
| [Playwright](https://playwright.dev/) | `output/visual` | with `pixelmatch` and `pngjs` |
| [libxml2](https://gitlab.gnome.org/GNOME/libxml2), for `xmllint` | `output/feeds` | the feeds and sitemap parse |

Two of them drive a browser. Playwright installs one, and the perf gate
finds it. A system Chrome or Chromium works as well.

`./c help check` lists every gate and the script behind it.

### Checking the template itself

The template carries no theme, so most gates have nothing to read. `./c
check` in it runs the `template` gate, which is the subset needing no
theme: coverage, portability, ShellCheck and the comment rules.

Without it the template's own README and changelog were read by nothing,
because bootstrap replaces both and no generated project ever sees
them.

## The gates

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

| Gate | What it reads |
|---|---|
| static | the sources, with no build |
| build | four builds, and the scale fixture |
| output | the built pages |
| release | the tag, the changelog and the module path |

A check whose tool is missing prints `SKIP`. That is a warning on a
workstation and a failure in CI, where the image carries every tool.

## Features

A feature is an optional element the theme renders, registered to a slot
and switched by one line. `./c feature list` shows them.

Twelve features ship installed. Seven are on and five are off, and one
line in the config moves any of them. A feature is never edited out of a
template.

```sh
./c feature list          every feature, installed or available
./c feature add name=x    install one the template ships
./c feature new name=x    start one of your own
./c feature off name=x    write the switch into the fixture config
```

`./c feature add` is the path for anything beyond the starter set. The
catalogue it copies from stays in `templates/feature/`, so a feature
removed from a project can be put back.

### Two levels

A **toggle** is a partial in the theme, wired to a slot and switched by
one line. Most features are toggles.

A **component** is a directory under `features/` with its own layouts,
assets and words, mounted beside the theme. Turning one off means not
mounting it, which is what makes it a component rather than a toggle.

`privacy-embeds` overrides Hugo's `youtube`, `vimeo` and `x` with a
poster and a link, so a page loads nothing from another host until the
reader follows it. A site without the component gets Hugo's own
renderings back, so the shortcode names in the content stay portable.

`search` publishes a JSON index and a search page. The page lists every
page in its own markup. A reader with the script blocked then has a
working index rather than an empty box. The script filters that list and fetches
nothing. The index is held under 1.5 MB by a gate.

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
goes stale, and a declaration cannot.
