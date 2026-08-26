#!/usr/bin/env bash
# One command. Every action goes through it, locally and in CI, so a
# green run here predicts a green run there.
#
# Arguments are key=value in any order, plus bare verbs. ./c help prints
# the table.
#
# Exit codes: 0 pass, 1 findings, 2 usage, 3 missing tool.
set -euo pipefail
cd "$(dirname "$0")"

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. scripts/python.sh answers both questions.
PY_BIN="$(scripts/python.sh 2>/dev/null || echo python3)"


ROOT="$(pwd -P)"
STAGE=conformance/public
VERB=""
declare -A ARG=()

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
          theme|name|gate|size|site|v) ARG["$key"]="${item#*=}" ;;
          *) printf '%s\n' "unknown key: $key" >&2; usage 2 ;;
        esac
        ;;
      init|check|conform|serve|release|snapshot|fixture|docs|report|feature|clean|version|help)
        if [ -z "$VERB" ]; then
          VERB="$item"
        else
          ARG["sub"]="$item"
        fi
        ;;
      list|new|on|off|add|available)
        ARG["sub"]="$item"
        ;;
      --strict) ARG["strict"]=yes ;;
      *) printf '%s\n' "unknown argument: $item" >&2; usage 2 ;;
    esac
  done
}

need() {
  local key="$1"
  [ -n "${ARG[$key]:-}" ] || { printf '%s\n' "missing $key=" >&2; usage 2; }
}

say() { printf '%s\n' "$*"; }

# --------------------------------------------------------------- checks

bootstrapped() {
  [ -d layouts ] || {
    say "no theme yet. Run ./c init name=<slug> first."
    exit 2
  }
}

# ---------------------------------------------------------------- verbs

cmd_version() {
  local installed pinned
  installed="$(scripts/hugo-version.sh)"
  pinned="$(cat .hugo-version 2>/dev/null || echo "none")"
  say "hugo installed: $installed"
  say "hugo pinned:    $pinned"
}

cmd_init() {
  need name
  scripts/bootstrap.sh "${ARG[name]}"
}

# Resolve theme= into the config files that select it.
theme_config() {
  local theme="$1"
  case "$theme" in
    ours) printf 'hugo.toml,config/ours/hugo.toml\n' ;;
    hugo|reference) printf 'hugo.toml,config/hugo/hugo.toml\n' ;;
    *)
      [ -d "conformance/themes/$theme" ] || {
        printf '%s\n' "no theme at conformance/themes/$theme" >&2; exit 2; }
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
  ( cd conformance && hugo --config "$config" -d "public/$dest" \
      --panicOnWarning --printPathWarnings --printUnusedTemplates \
      --printI18nWarnings --logLevel warn --gc "$@" )
}

# Build any real Hugo site against the theme. The kitchen sink covers
# what Hugo can do. This covers what a site does.
cmd_site() {
  bootstrapped
  local site="${ARG[site]}" config dir
  [ -d "$site" ] || { printf '%s\n' "no site at $site" >&2; exit 2; }
  # Relative to conformance/, because an absolute path from Git Bash
  # reads as /c/Users/... and the Windows Hugo binary cannot open one.
  local absolute
  absolute="$(cd "$site" && pwd -P)"
  site="$("$PY_BIN" -c 'import os,sys;print(os.path.relpath(sys.argv[1], sys.argv[2]).replace(os.sep, "/"))' \
    "$absolute" "$ROOT/conformance")"
  scripts/reference.sh
  config=conformance/config/site/hugo.toml
  mkdir -p "$(dirname "$config")"

  # Every mount goes in this one file. Hugo replaces the mounts array
  # when two configs both declare one, rather than joining them, so a
  # second file holding only the site's mounts would drop the theme's.
  {
    printf '%s\n' "# Written by ./c site=. Do not edit."
    printf '%s\n' "#"
    printf '%s\n' "# The theme key is emptied. The site names a theme of its own,"
    printf '%s\n' "# and that directory is not here. The theme under test is"
    printf '%s\n' "# mounted from the repository root instead."
    printf '%s\n' "theme = []"
    printf '%s\n' "[module]"
    for dir in layouts archetypes assets i18n static data; do
      # The test runs from the repository root. The path written is
      # relative to conformance/, which is where Hugo reads it.
      [ -d "$dir" ] || continue
      printf '  [[module.mounts]]\n    source = "../%s"\n    target = "%s"\n' "$dir" "$dir"
    done
    for dir in content assets static i18n data layouts archetypes; do
      [ -d "$site/$dir" ] || continue
      printf '  [[module.mounts]]\n    source = "%s"\n    target = "%s"\n' "$site/$dir" "$dir"
    done
  } > "$config"

  # The site's own config merges under the conformance config, so its
  # taxonomies and menus apply while the conformance settings still win.
  local extra=""
  [ -f "$site/hugo.toml" ] && extra="$site/hugo.toml,"
  say "build $site against the theme"
  ( cd conformance && hugo --config "hugo.toml,${extra}config/site/hugo.toml" \
      -d public/site --panicOnWarning --printPathWarnings \
      --printI18nWarnings --logLevel warn --gc )
}

cmd_build() {
  local theme="${ARG[theme]:-all}"
  bootstrapped
  scripts/reference.sh
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
  local theme="${ARG[theme]:-ours}" config
  scripts/reference.sh
  config="$(theme_config "$theme")"
  ( cd conformance && hugo server --config "$config" )
}

cmd_conform() {
  bootstrapped
  conformance/scripts/conform.sh
}

cmd_check() {
  bootstrapped
  local gate="${ARG[gate]:-}" name="${ARG[name]:-}"
  scripts/check/run.sh "$gate" "$name"
}

cmd_snapshot() {
  bootstrapped
  ARG[theme]=ours
  cmd_build
  rm -rf conformance/snapshots/skeleton
  mkdir -p conformance/snapshots/skeleton
  "$PY_BIN" conformance/scripts/skeleton.py "$STAGE/ours" \
    --out conformance/snapshots/skeleton
  say "snapshot refreshed from $STAGE/ours"
}

cmd_fixture() {
  local size="${ARG[size]:-2000}"
  "$PY_BIN" conformance/scripts/fixture.py --size "$size"
}

cmd_docs() {
  bootstrapped
  scripts/docs.sh
}

cmd_report() {
  "$PY_BIN" conformance/scripts/report.py
}

cmd_clean() {
  rm -rf conformance/public resources/_gen conformance/resources/_gen \
         .tools .hugo_build.lock conformance/.hugo_build.lock public
  say "removed build output and fetched tools"
}

cmd_feature() {
  bootstrapped
  local sub="${ARG[sub]:-list}"
  case "$sub" in
    list) scripts/feature.sh list ;;
    available) scripts/feature.sh available ;;
    add)  need name; scripts/feature.sh add "${ARG[name]}" ;;
    new)  need name; scripts/feature.sh new "${ARG[name]}" ;;
    on)   need name; scripts/feature.sh on "${ARG[name]}" ;;
    off)  need name; scripts/feature.sh off "${ARG[name]}" ;;
    *) printf '%s\n' "unknown feature action: $sub" >&2; usage 2 ;;
  esac
}

cmd_release() {
  bootstrapped
  need v
  scripts/release.sh "${ARG[v]}"
}

cmd_help() {
  if [ "${ARG[sub]:-}" = "check" ]; then
    printf '%s\n' "Gates run in order, cheapest first, stopping at the first failure."
    printf '\n%s\n' "Every check is a script under scripts/check, runnable alone."
    printf '%s\n\n' "Exit codes: 0 pass, 1 findings, 2 usage, 3 missing tool."
    scripts/check/run.sh --list
    exit 0
  fi
  usage 0
}

# ------------------------------------------------------------- dispatch

parse "$@"

case "$VERB" in
  "")        if [ -n "${ARG[site]:-}" ]; then cmd_site; else cmd_build; fi ;;
  init)      cmd_init ;;
  check)     cmd_check ;;
  conform)   cmd_conform ;;
  serve)     cmd_serve ;;
  snapshot)  cmd_snapshot ;;
  fixture)   cmd_fixture ;;
  docs)      cmd_docs ;;
  report)    cmd_report ;;
  feature)   cmd_feature ;;
  release)   cmd_release ;;
  clean)     cmd_clean ;;
  version)   cmd_version ;;
  help)      cmd_help ;;
  *)         usage 2 ;;
esac

# USAGE
# ./c theme=ours                  build the fixture against the theme at the root
# ./c theme=hugo                  build against the scaffold of the installed Hugo
# ./c theme=all                   both, into public/ours and public/hugo
# ./c theme=ours serve            hugo server with live reload
# ./c init name=my-theme          bootstrap, one-shot
# ./c check                       every gate in order, stop at first failure
# ./c check gate=static           one gate: static, build, output, release
# ./c check name=head             one script by name
# ./c conform                     theme=all, then file-list and skeleton diff
# ./c release v=1.2.0             gate release, tag, push, publish
# ./c snapshot                    refresh conformance/snapshots/ from the current ours build
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
# ./c clean                       remove public/, resources/_gen, .tools/, the lock file
# ./c version                     print the installed Hugo version and .hugo-version
# ./c help
# END
