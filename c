#!/usr/bin/env bash
# One command. Every action goes through it, locally and in CI, so a
# green run here predicts a green run there.
#
# Arguments are key=value in any order, plus bare verbs. ./c help prints
# the table.
#
# Exit codes: 0 pass, 1 findings, 2 usage, 3 missing tool.
set -euo pipefail
cd "$(dirname "$0")" || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"


ROOT="$(pwd -P)"
STAGE=tools/conformance/public
VERB=""
# One variable per key rather than an associative array, which is
# bash 4, and the bash a stock Mac ships is 3.2.
ARG_theme=""
ARG_name=""
ARG_owner=""
ARG_repo=""
ARG_gate=""
ARG_size=""
ARG_site=""
ARG_v=""
ARG_sub=""

# ------------------------------------------------------------ arguments

usage() {
  sed -n '/^# USAGE$/,/^# END$/p' "$0" | sed '1d;$d;s/^# \{0,1\}//'
  exit "${1:-2}"
}

parse() {
  local item key
  for item in "$@"; do
    case "$item" in
      *=*)
        key="${item%%=*}"
        case "$key" in
          theme) ARG_theme="${item#*=}" ;;
          name)  ARG_name="${item#*=}" ;;
          owner) ARG_owner="${item#*=}" ;;
          repo)  ARG_repo="${item#*=}" ;;
          gate)  ARG_gate="${item#*=}" ;;
          size)  ARG_size="${item#*=}" ;;
          site)  ARG_site="${item#*=}" ;;
          v)     ARG_v="${item#*=}" ;;
          *) printf '%s\n' "unknown key: $key" >&2; usage 2 ;;
        esac
        ;;
      init|build|setup|check|conform|serve|release|snapshot|fixture|docs|report|feature|package|clean|version|help)
        if [ -z "$VERB" ]; then
          VERB="$item"
        else
          ARG_sub="$item"
        fi
        ;;
      list|new|on|off|add|available|full)
        ARG_sub="$item"
        ;;
      *) printf '%s\n' "unknown argument: $item" >&2; usage 2 ;;
    esac
  done
}

need() {
  local key="$1" var="ARG_$1"
  [ -n "${!var:-}" ] || { printf '%s\n' "missing $key=" >&2; usage 2; }
}

say() { printf '%s\n' "$*"; }

# --------------------------------------------------------------- checks

bootstrapped() {
  [ -d layouts ] || {
    say "no theme yet. Run ./c init name=<name> first."
    exit 2
  }
}

# ---------------------------------------------------------------- verbs

cmd_version() {
  local installed pinned
  installed="$(tools/scripts/hugo-version.sh)"
  pinned="$(cat .hugo-version 2>/dev/null || echo "none")"
  say "hugo installed: $installed"
  say "hugo pinned:    $pinned"
}

cmd_init() {
  need name
  # The owner and the repository are optional. Given, they go into
  # theme.toml. Absent, bootstrap reads them from the git remote.
  tools/scripts/bootstrap.sh "$ARG_name" "${ARG_owner:-}" "${ARG_repo:-}"
}

# Resolve theme= into the config files that select it.
theme_config() {
  local theme="$1"
  case "$theme" in
    ours) printf 'hugo.toml,config/ours/hugo.toml\n' ;;
    dev)  printf 'hugo.toml,config/dev/hugo.toml\n' ;;
    hugo|reference) printf 'hugo.toml,config/hugo/hugo.toml\n' ;;
    *)
      [ -d "tools/conformance/themes/$theme" ] || {
        printf '%s\n' "no theme at tools/conformance/themes/$theme" >&2; exit 2; }
      printf 'hugo.toml,config/%s/hugo.toml\n' "$theme"
      ;;
  esac
}

build_one() {
  local theme="$1" dest="$2"
  shift 2
  local config
  config="$(theme_config "$theme")"
  say "build $theme -> $dest"
  ( cd tools/conformance && hugo --config "$config" -d "public/$dest" \
      --panicOnWarning --printPathWarnings --printUnusedTemplates \
      --printI18nWarnings --logLevel warn --gc "$@" )
}

# Build any real Hugo site against the theme. The kitchen sink covers
# what Hugo can do. This covers what a site does.
cmd_site() {
  bootstrapped
  local site="$ARG_site" config dir
  [ -d "$site" ] || { printf '%s\n' "no site at $site" >&2; exit 2; }
  # Relative to tools/conformance/, because an absolute path from Git Bash
  # reads as /c/Users/... and the Windows Hugo binary cannot open one.
  local absolute
  absolute="$(cd "$site" && pwd -P)"
  site="$("$PY_BIN" -c 'import os,sys;print(os.path.relpath(sys.argv[1], sys.argv[2]).replace(os.sep, "/"))' \
    "$absolute" "$ROOT/conformance")"
  tools/scripts/configs.sh >/dev/null
  tools/scripts/reference.sh
  local slug
  slug="$(tools/scripts/slug.sh)"
  config=tools/conformance/config/site/hugo.toml
  mkdir -p "$(dirname "$config")"

  # Every mount goes in this one file. Hugo replaces the mounts array
  # when two configs both declare one, rather than joining them, so a
  # second file holding only the site's mounts would drop the theme's.
  {
    printf '%s\n' "# Written by ./c site=. Do not edit."
    printf '%s\n' "#"
    printf '%s\n' "# The site's own theme is replaced by the one under test,"
    printf '%s\n' "# read out of dist/ the way a downloader reads it."
    printf 'theme = "%s"\n' "$slug"
    printf '%s\n' 'themesDir = "../../dist"'
    printf '%s\n' "[module]"
    for dir in content assets static i18n data layouts archetypes; do
      [ -d "$site/$dir" ] || continue
      printf '  [[module.mounts]]\n    source = "%s"\n    target = "%s"\n' "$site/$dir" "$dir"
    done
  } > "$config"

  # The site's own config merges under the tools/conformance config, so its
  # taxonomies and menus apply while the tools/conformance settings still win.
  local extra=""
  [ -f "$site/hugo.toml" ] && extra="$site/hugo.toml,"
  say "build $site against the theme"
  ( cd tools/conformance && hugo --config "hugo.toml,${extra}config/site/hugo.toml" \
      -d public/site --panicOnWarning --printPathWarnings \
      --printI18nWarnings --logLevel warn --gc )
}

cmd_build() {
  local theme="${ARG_theme:-all}"
  bootstrapped
  tools/scripts/configs.sh >/dev/null
  tools/scripts/reference.sh
  case "$theme" in
    all)
      build_one hugo hugo
      build_one ours ours
      ;;
    *) build_one "$theme" "$theme" ;;
  esac
}

cmd_serve() {
  bootstrapped
  local theme="${ARG_theme:-dev}" config
  tools/scripts/configs.sh >/dev/null
  tools/scripts/reference.sh
  # serve reads the sources, so an edit shows up without a repack.
  # Everything else reads the artefact. The one place the two shapes
  # differ is a component's mount, and the install gate is what holds
  # that honest.
  [ "$theme" = dev ] && say "serve reads the sources. check reads the package."
  config="$(theme_config "$theme")"
  ( cd tools/conformance && hugo server --config "$config" )
}

cmd_conform() {
  bootstrapped
  tools/conformance/scripts/conform.sh
}

cmd_check() {
  local gate="${ARG_gate:-}" name="${ARG_name:-}"
  # With no theme, only the checks that need none can run. That is the
  # template repository itself, which otherwise held its own prose and
  # tools/scripts to nothing, because a project replaces the README it reads.
  if [ ! -d layouts ]; then
    if [ -n "$gate" ] && [ "$gate" != template ]; then
      say "no theme yet, so gate=$gate cannot run. Try ./c check gate=template."
      exit 2
    fi
    say "no theme here, so reading what needs none"
    tools/scripts/check/run.sh template "$name"
    return
  fi
  tools/scripts/check/run.sh "$gate" "$name"
}

# Bare ./c: check, then compile. The gates run in order, and on green
# the artefact is named. set -e stops on a red gate, so nothing broken
# is ever handed over.
cmd_compile() {
  cmd_check
  # The template repository holds no theme, so there is nothing to
  # hand over. cmd_check has already read what needs none.
  [ -d layouts ] || return 0
  local slug zip skipped
  slug="$(tools/scripts/slug.sh)"
  zip="$(find dist -maxdepth 1 -name "$slug-*.zip" -type f 2>/dev/null | head -1)"
  [ -n "$zip" ] || { say "no artefact. The package check skipped, so nothing wrote one."; exit 3; }
  say ""
  # A skipped check is a check this artefact never faced. The line
  # that hands the zip over says so, rather than leaving green to
  # mean more than it does.
  skipped="$(sed -n 's/.*, \([0-9][0-9]*\) skipped$/\1/p' tools/conformance/public/tally.txt 2>/dev/null)"
  if [ -n "$skipped" ] && [ "$skipped" -gt 0 ]; then
    say "the deliverable: $zip, after $skipped skipped checks."
    say "./c setup fetches the missing tools. CI and the release run them all."
  else
    say "the deliverable: $zip"
  fi
}

cmd_snapshot() {
  bootstrapped
  ARG_theme=ours
  cmd_build
  rm -rf tools/conformance/snapshots/skeleton
  mkdir -p tools/conformance/snapshots/skeleton
  "$PY_BIN" tools/conformance/scripts/skeleton.py "$STAGE/ours" \
    --out tools/conformance/snapshots/skeleton
  # The screenshots are part of the snapshot. Without this the visual
  # gate had no baseline to compare against, ever.
  if command -v node >/dev/null 2>&1; then
    mkdir -p tools/conformance/snapshots/screens
    # The same global module path the visual gate needs.
    if [ -z "${NODE_PATH:-}" ] && command -v npm >/dev/null 2>&1; then
      NODE_PATH="$(npm root -g 2>/dev/null || true)"
      export NODE_PATH
    fi
    if node tools/conformance/scripts/visual.js --write; then
      say "screenshots refreshed"
    else
      say "screenshots not written. playwright, pixelmatch and pngjs are needed."
    fi
  else
    say "screenshots not written. node is not installed."
  fi
  say "snapshot refreshed from $STAGE/ours"
}

cmd_fixture() {
  local size="${ARG_size:-2000}"
  "$PY_BIN" tools/conformance/scripts/fixture.py --size "$size"
}

cmd_docs() {
  bootstrapped
  tools/scripts/docs.sh
}

cmd_setup() {
  tools/scripts/setup.sh "${ARG_sub:-}"
}

cmd_report() {
  "$PY_BIN" tools/conformance/scripts/report.py
}

cmd_package() {
  bootstrapped
  tools/scripts/package.sh
}

cmd_clean() {
  rm -rf tools/conformance/public resources/_gen tools/conformance/resources/_gen \
         tools/.deps .hugo_build.lock tools/conformance/.hugo_build.lock public dist
  say "removed build output, the artefact and fetched tools"
}

cmd_feature() {
  bootstrapped
  local sub="${ARG_sub:-list}"
  case "$sub" in
    list) tools/scripts/feature.sh list ;;
    available) tools/scripts/feature.sh available ;;
    add)  need name; tools/scripts/feature.sh add "$ARG_name" ;;
    new)  need name; tools/scripts/feature.sh new "$ARG_name" ;;
    on)   need name; tools/scripts/feature.sh on "$ARG_name" ;;
    off)  need name; tools/scripts/feature.sh off "$ARG_name" ;;
    *) printf '%s\n' "unknown feature action: $sub" >&2; usage 2 ;;
  esac
}

cmd_release() {
  bootstrapped
  need v
  tools/scripts/release.sh "$ARG_v"
}

cmd_help() {
  if [ "${ARG_sub:-}" = "check" ]; then
    printf '%s\n' "Gates run in order, cheapest first, stopping at the first failure."
    printf '\n%s\n' "Every check is a script under tools/scripts/check, runnable alone."
    printf '%s\n\n' "Exit codes: 0 pass, 1 findings, 2 usage, 3 missing tool."
    tools/scripts/check/run.sh --list
    exit 0
  fi
  usage 0
}

# ------------------------------------------------------------- dispatch

parse "$@"

case "$VERB" in
  # Bare ./c with a site= or theme= argument keeps its old meaning, a
  # build of that thing. With no argument at all it is the promise of
  # the repository: every gate, then the deliverable.
  "")        if [ -n "${ARG_site:-}" ]; then cmd_site
             elif [ -n "${ARG_theme:-}" ]; then cmd_build
             else cmd_compile; fi ;;
  init)      cmd_init ;;
  build)     cmd_build ;;
  setup)     cmd_setup ;;
  check)     cmd_check ;;
  conform)   cmd_conform ;;
  serve)     cmd_serve ;;
  snapshot)  cmd_snapshot ;;
  fixture)   cmd_fixture ;;
  docs)      cmd_docs ;;
  report)    cmd_report ;;
  feature)   cmd_feature ;;
  release)   cmd_release ;;
  package)   cmd_package ;;
  clean)     cmd_clean ;;
  version)   cmd_version ;;
  help)      cmd_help ;;
  *)         usage 2 ;;
esac

# USAGE
# ./c                             every gate, then the deliverable in dist/
# ./c build theme=ours            build the fixture against the packaged theme
# ./c build theme=hugo            build against the scaffold of the installed Hugo
# ./c build theme=all             both, into public/ours and public/hugo
# ./c serve                       hugo server, reading the sources, live reload
# ./c init name="My Theme"        bootstrap, one-shot. The slug is derived
# ./c init name=x owner=y repo=z  and the URLs in theme.toml are filled in
# ./c setup                       what this machine has, then fetch the light tier
# ./c setup full                  the browser tier too, Chromium included
# ./c setup report                only look
# ./c check                       every gate in order, stop at first failure
# ./c check gate=static           one gate: static, build, output, release
# ./c package                     write dist/<slug>/ and the zip a downloader gets
# ./c check name=head             one script by name
# ./c conform                     theme=all, then file-list and skeleton diff
# ./c release v=1.2.0             gate release, tag, push, publish
# ./c snapshot                    refresh tools/conformance/snapshots/ from the current ours build
# ./c fixture size=2000           generate the scale fixture
# ./c site=../some-site           build a real site against ours
# ./c docs                        regenerate contract.toml and docs/front-matter.md
# ./c report                      write the PR report to public/report/
# ./c feature list                name, slot, default, level, one line each
# ./c feature available          the features the template ships and has not installed
# ./c feature add name=x          install one of those, whole
# ./c feature new name=x          write the manifest, partial, css, i18n key and fixture page
# ./c feature on name=x
# ./c feature off name=x
# ./c clean                       remove public/, dist/, resources/_gen, tools/.deps/
# ./c version                     print the installed Hugo version and .hugo-version
# ./c help
# END
