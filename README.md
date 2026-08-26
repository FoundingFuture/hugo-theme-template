# hugo-theme-template

A GitHub template that produces a Hugo theme project. The template holds
no theme. The first command generates one from whichever Hugo is
installed that day. A project never starts from a scaffold frozen when
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

The GitHub "Use this template" button copies the files and runs
nothing. So `bootstrap.yml` runs `./c init` on the first push, and then
never triggers again.

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

## The gates

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

A manifest declares what the feature adds to the rendered page. The
fixture builds three times. The reference scaffold, the theme with every
feature off, and the theme with them at their defaults.

With the features off the theme has to match the scaffold exactly. With
them on, the only differences allowed are the ones the manifests
declared. A manifest names the container its links and headings sit in,
the classed elements it adds, and the elements it adds more of. A
feature that changes anything else fails the build.

The h1 is nobody's to add. The reference and the theme are compared on
the h1 of every page, by itself, so that claim cannot go quiet.

Nothing is kept in an ignore list. That is the point. An ignore list
goes stale, and a declaration cannot.
