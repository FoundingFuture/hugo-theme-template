#!/usr/bin/env bash
# What the pipeline needs, what this machine has, and what to do about
# the difference. Bare, it reports and then fetches the light tier.
# With full, the browser tier comes too. With report, it only looks.
#
# Three ways a tool arrives. Fetched into the tree by tools.sh, where
# a pinned build exists. Installed by the machine's package manager,
# where one is present. Or named here with the command to run, and
# left to the reader.
# reads: tools/scripts/tools.sh
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

MODE="${1:-fetch}"

LIGHT="shellcheck htmltest hugo-latest stylelint eslint"
FULL="html5validator pa11y-ci lhci playwright"

manager=""
if command -v brew >/dev/null 2>&1; then manager=brew
elif command -v apt-get >/dev/null 2>&1; then manager=apt
elif command -v dnf >/dev/null 2>&1; then manager=dnf
elif command -v pacman >/dev/null 2>&1; then manager=pacman
elif command -v winget.exe >/dev/null 2>&1 || command -v winget >/dev/null 2>&1; then manager=winget
fi

say() { printf '%s\n' "$*"; }
row() { printf '%-15s %-34s %s\n' "$1" "$2" "$3"; }

# Where a fetched tool sits, said the way a reader thinks of it.
place_of() {
  case "$1" in
    */.deps/*) printf 'in the tree' ;;
    */node_modules/*) printf 'in the tree' ;;
    *) printf 'on PATH' ;;
  esac
}

state_of() {
  local tool="$1" dir version
  case "$tool" in
    hugo)
      command -v hugo >/dev/null 2>&1 || { printf 'missing'; return 1; }
      version="$(hugo version 2>/dev/null | sed -n 's/^hugo v\([0-9.]*\).*/\1/p')"
      if tools/scripts/hugo-extended.sh >/dev/null 2>&1; then
        printf '%s extended' "$version"
      else
        printf '%s, and not extended' "$version"
        return 1
      fi
      ;;
    python3)
      version="$(tools/scripts/python.sh 2>/dev/null)" || { printf 'missing'; return 1; }
      printf '%s' "$("$version" --version 2>&1 | awk '{print $2}')"
      ;;
    node)
      command -v node >/dev/null 2>&1 || { printf 'missing'; return 1; }
      printf '%s' "$(node --version)"
      ;;
    go)
      command -v go >/dev/null 2>&1 || { printf 'missing'; return 1; }
      printf '%s' "$(go version 2>/dev/null | awk '{print $3}')"
      ;;
    java)
      command -v java >/dev/null 2>&1 || { printf 'missing'; return 1; }
      printf 'present'
      ;;
    *)
      dir="$(tools/scripts/tools.sh "$tool" 2>/dev/null)" || { printf 'missing'; return 1; }
      printf '%s' "$(place_of "$dir")"
      ;;
  esac
}

report() {
  local tool state
  say "tool            state                              unlocks"
  for tool in hugo python3 node go java; do
    state="$(state_of "$tool")" || true
    case "$tool" in
      hugo) row hugo "$state" "everything, and it is yours to install" ;;
      python3) row python3 "$state" "most checks" ;;
      node) row node "$state" "the five npm tools" ;;
      go) row go "$state" "release/module" ;;
      java) row java "$state" "html5validator" ;;
    esac
  done
  for tool in $LIGHT; do
    state="$(state_of "$tool")" || state="missing. ./c setup fetches it"
    row "$tool" "$state" "$(unlocks "$tool")"
  done
  for tool in $FULL; do
    state="$(state_of "$tool")" || state="missing. ./c setup full fetches it"
    row "$tool" "$state" "$(unlocks "$tool")"
  done
}

unlocks() {
  case "$1" in
    shellcheck) printf 'static/shellcheck' ;;
    htmltest) printf 'output/validity, output/nojs' ;;
    hugo-latest) printf 'build/versions' ;;
    stylelint) printf 'static/css' ;;
    eslint) printf 'static/js' ;;
    html5validator) printf 'output/validity, and it drives Java' ;;
    pa11y-ci) printf 'output/a11y, and it drives a browser' ;;
    lhci) printf 'output/perf, and it drives a browser' ;;
    playwright) printf 'output/visual, Chromium included' ;;
  esac
}

# The package manager covers what cannot land in the tree. Nothing
# runs without the reader seeing the command first.
manage() {
  local tool="$1" cmd=""
  case "$manager:$tool" in
    brew:hugo) cmd="brew install hugo" ;;
    winget:hugo) cmd="winget install Hugo.Hugo.Extended" ;;
    pacman:hugo) cmd="sudo pacman -S --noconfirm hugo" ;;
    brew:node) cmd="brew install node" ;;
    apt:node) cmd="sudo apt-get install -y nodejs npm" ;;
    dnf:node) cmd="sudo dnf install -y nodejs" ;;
    pacman:node) cmd="sudo pacman -S --noconfirm nodejs npm" ;;
    winget:node) cmd="winget install OpenJS.NodeJS.LTS" ;;
    brew:go) cmd="brew install go" ;;
    apt:go) cmd="sudo apt-get install -y golang-go" ;;
    dnf:go) cmd="sudo dnf install -y golang" ;;
    pacman:go) cmd="sudo pacman -S --noconfirm go" ;;
    winget:go) cmd="winget install GoLang.Go" ;;
    apt:java) cmd="sudo apt-get install -y default-jre-headless" ;;
    dnf:java) cmd="sudo dnf install -y java-21-openjdk-headless" ;;
    pacman:java) cmd="sudo pacman -S --noconfirm jre-openjdk-headless" ;;
    winget:java) cmd="winget install EclipseAdoptium.Temurin.21.JRE" ;;
  esac
  if [ -z "$cmd" ]; then
    hint "$tool"
    return 0
  fi
  say "setup: $cmd"
  $cmd || hint "$tool"
}

# The line a reader follows when no manager can help here.
hint() {
  case "$1" in
    hugo) say "install Hugo extended yourself: https://gohugo.io/installation/" ;;
    node) say "install Node 20 or later yourself: https://nodejs.org/" ;;
    go) say "install Go yourself, for release/module: https://go.dev/dl/" ;;
    java) say "install a Java runtime yourself, for html5validator" ;;
  esac
}

fetch_tier() {
  local tool
  for tool in $1; do
    if tools/scripts/tools.sh "$tool" >/dev/null 2>&1; then
      continue
    fi
    say "setup: fetching $tool"
    tools/scripts/tools.sh "$tool" fetch >/dev/null || say "setup: $tool did not arrive"
  done
}

report
[ "$MODE" = report ] && exit 0

say ""
state_of hugo >/dev/null || manage hugo
state_of node >/dev/null || manage node
state_of go >/dev/null || manage go
fetch_tier "$LIGHT"
if [ "$MODE" = full ]; then
  state_of java >/dev/null || manage java
  fetch_tier "$FULL"
fi

say ""
say "after:"
report
