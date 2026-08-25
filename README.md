# hugo-theme-template

A GitHub template that produces a Hugo theme project. The template holds
no theme. The first command generates one from whichever Hugo is
installed that day, so a project never starts from a scaffold frozen
when the template was written.

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

Using the GitHub "Use this template" button copies the files and runs
nothing, so `bootstrap.yml` runs `./c init` on the first push and then
deletes itself.

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

The file list, so the theme publishes the same pages, feeds, aliases and
sitemap entries. Then the skeleton of every page: the heading outline,
the links and images inside the content, and the counts of the block
elements. Markup and styling are free to differ. What a reader can find
on the page is not.

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

The mechanism ships wired and empty. A feature arrives whole, through
`./c feature new`, with its manifest, partial, stylesheet, words and a
fixture page. The static gate fails until every piece is there.
