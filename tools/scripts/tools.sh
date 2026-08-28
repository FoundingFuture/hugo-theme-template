#!/usr/bin/env bash
# Fetch a pinned tool into the tree when it is not already on PATH.
#
# Usage: tools/scripts/tools.sh <tool> [fetch]
# Prints the directory holding the tool, or exits 3. Bare, it only
# looks. With fetch, a missing tool is brought into the tree first.
# A release binary lands in tools/.deps/bin, a node tool in
# node_modules, a Python tool in the shared venv.
#
# uv is preferred, because it carries its own Python and needs no
# ensurepip. A Debian box without python3-venv cannot build a virtual
# environment with pip in it. That is the common case handled here.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

SHELLCHECK_TAG=v0.11.0
HTMLTEST_TAG=v0.17.0

venv=tools/.deps/venv
BIN=tools/.deps/bin

# The version a pinned tool must be. Empty means any copy serves.
pin_of() {
  case "$1" in
    shellcheck) printf '%s' "${SHELLCHECK_TAG#v}" ;;
    htmltest) printf '%s' "${HTMLTEST_TAG#v}" ;;
  esac
}

binary_version() {
  local bin="$1"
  case "$bin" in
    *shellcheck*) "$bin" --version 2>/dev/null | sed -n 's/^version: //p' ;;
    *htmltest*) "$bin" --version 2>/dev/null | awk '{print $2}' ;;
  esac
}

# Where a plain binary lives: PATH first, the fetched copy second. A
# PATH copy of a pinned tool serves only at the pinned version. The
# runner image carries an older shellcheck. Taking it made the
# findings differ by machine, while both runs claimed the same check.
locate_binary() {
  local name="$1" want dir
  want="$(pin_of "$name")"
  if command -v "$name" >/dev/null 2>&1; then
    dir="$(dirname "$(command -v "$name")")"
    if [ -z "$want" ] || [ "$(binary_version "$dir/$name")" = "$want" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
  fi
  if [ -x "$BIN/$name" ] || [ -x "$BIN/$name.exe" ]; then
    ( cd "$BIN" && pwd -P )
    return 0
  fi
  return 1
}

# Where a node tool lives: PATH first, tools/node_modules second. npm
# writes a shell shim beside the .cmd one, so the same path answers
# under Git Bash too.
locate_node() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    dirname "$(command -v "$name")"
    return 0
  fi
  if [ -x "tools/node_modules/.bin/$name" ]; then
    ( cd tools/node_modules/.bin && pwd -P )
    return 0
  fi
  return 1
}

platform() {
  local os arch
  case "$(uname -s)" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
    MINGW*|MSYS*|CYGWIN*) os=windows ;;
    *) return 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch=x86_64 ;;
    arm64|aarch64) arch=aarch64 ;;
    *) return 1 ;;
  esac
  printf '%s %s\n' "$os" "$arch"
}

newest_hugo() {
  curl -fsSL https://api.github.com/repos/gohugoio/hugo/releases/latest \
    | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1
}

# Download one release archive and put one binary from it into
# tools/.deps/bin. The zips are read by archive.py: Git for Windows
# ships no unzip, and the reader is already here.
fetch_binary() {
  local name="$1"
  local os arch url want out ver part found py
  read -r os arch < <(platform) || true
  [ -n "${os:-}" ] || {
    printf '%s\n' "no build maps to $(uname -s) $(uname -m)." >&2
    return 1
  }
  want="$name"
  out="$name"
  case "$name" in
    shellcheck)
      if [ "$os" = windows ]; then
        if [ "$arch" != x86_64 ]; then
          printf '%s\n' "shellcheck ships no windows $arch build." >&2
          return 1
        fi
        url="https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_TAG}/shellcheck-${SHELLCHECK_TAG}.zip"
      else
        url="https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_TAG}/shellcheck-${SHELLCHECK_TAG}.${os}.${arch}.tar.gz"
      fi
      ;;
    htmltest)
      ver="${HTMLTEST_TAG#v}"
      case "$os" in darwin) part=macos ;; *) part="$os" ;; esac
      case "$arch" in x86_64) part="${part}_amd64" ;; aarch64) part="${part}_arm64" ;; esac
      if [ "$os" = windows ]; then
        url="https://github.com/wjdp/htmltest/releases/download/${HTMLTEST_TAG}/htmltest_${ver}_${part}.zip"
      else
        url="https://github.com/wjdp/htmltest/releases/download/${HTMLTEST_TAG}/htmltest_${ver}_${part}.tar.gz"
      fi
      ;;
    hugo-latest)
      ver="$(newest_hugo)"
      [ -n "$ver" ] || {
        printf '%s\n' "the newest Hugo release could not be read." >&2
        return 1
      }
      want=hugo
      case "$os" in
        # The only darwin asset is the installer package. pkgutil is on
        # every Mac, and expanding one needs no install.
        darwin) url="https://github.com/gohugoio/hugo/releases/download/v${ver}/hugo_extended_${ver}_darwin-universal.pkg" ;;
        windows) url="https://github.com/gohugoio/hugo/releases/download/v${ver}/hugo_extended_${ver}_windows-amd64.zip" ;;
        *)
          case "$arch" in x86_64) part=amd64 ;; aarch64) part=arm64 ;; esac
          url="https://github.com/gohugoio/hugo/releases/download/v${ver}/hugo_extended_${ver}_linux-${part}.tar.gz"
          ;;
      esac
      ;;
    *) return 1 ;;
  esac
  local scratch=tools/.deps/fetch
  rm -rf "$scratch"
  mkdir -p "$scratch" "$BIN"
  curl -fsSL -o "$scratch/archive" "$url" || {
    printf '%s\n' "$url could not be fetched." >&2
    return 1
  }
  case "$url" in
    *.zip)
      py="$(tools/scripts/python.sh 2>/dev/null || echo python3)"
      "$py" tools/scripts/archive.py extract "$scratch/archive" "$scratch/out" || return 1
      ;;
    *.pkg)
      pkgutil --expand-full "$scratch/archive" "$scratch/out" || return 1
      ;;
    *)
      mkdir -p "$scratch/out"
      tar -xzf "$scratch/archive" -C "$scratch/out" || return 1
      ;;
  esac
  found="$(find "$scratch/out" -type f \( -name "$want" -o -name "$want.exe" \) | head -1)"
  [ -n "$found" ] || {
    printf '%s\n' "no $want inside $url." >&2
    return 1
  }
  case "$found" in
    *.exe) mv "$found" "$BIN/$out.exe" ;;
    *) mv "$found" "$BIN/$out" && chmod +x "$BIN/$out" ;;
  esac
  rm -rf "$scratch"
}

# One package from PyPI into the shared venv, uv first for the same
# reason as above.
install_from_pypi() {
  local pkg="$1"
  if command -v uv >/dev/null 2>&1; then
    [ -x "$venv/bin/python" ] || uv venv --quiet "$venv" >/dev/null 2>&1
    if [ -x "$venv/bin/python" ] \
       && uv pip install --quiet --python "$venv/bin/python" "$pkg" >/dev/null 2>&1; then
      return 0
    fi
  fi
  command -v python3 >/dev/null 2>&1 || return 1
  [ -x "$venv/bin/pip" ] || python3 -m venv "$venv" >/dev/null 2>&1
  [ -x "$venv/bin/pip" ] || return 1
  "$venv/bin/pip" install --quiet "$pkg" >/dev/null 2>&1
}

specs() {
  # Plain https first. It needs no key and no token, which is what a
  # runner has. For a public repository that is enough.
  #
  # The list held only ssh and a token before. CI could reach neither,
  # so the step failed on every repository made from the template.
  printf '%s\n' "git+https://github.com/${WRITING_LINT_REPO}@${WRITING_LINT_TAG}"
  if [ -n "${GH_TOKEN:-}" ]; then
    printf '%s\n' "git+https://${GH_TOKEN}@github.com/${WRITING_LINT_REPO}@${WRITING_LINT_TAG}"
  fi
  # ssh, for a private fork and for a workstation with a key. The host
  # alias is tried too, since a clone may have been made through one.
  printf '%s\n' "git+ssh://git@github.com/${WRITING_LINT_REPO}@${WRITING_LINT_TAG}"
  printf '%s\n' "git+ssh://git@github-ff/${WRITING_LINT_REPO}@${WRITING_LINT_TAG}"
}

# The version an entry point would run, asked of the interpreter named
# in its first line. A console script is written by the installer, so
# that line points at the environment holding the package.
version_of() {
  local script="$1" interpreter
  [ -x "$script" ] || return 0
  interpreter="$(sed -n '1s|^#!||p' "$script" | awk '{print $1}')"
  [ -x "$interpreter" ] || return 0
  "$interpreter" -c 'import writing_lint, sys; sys.stdout.write(writing_lint.__version__)' \
    2>/dev/null || true
}

install_with_uv() {
  command -v uv >/dev/null 2>&1 || return 1
  # Fail rather than ask. A private repository would otherwise stop the
  # run at a password prompt that nobody is there to answer.
  export GIT_TERMINAL_PROMPT=0
  [ -x "$venv/bin/python" ] || uv venv --quiet "$venv" >/dev/null 2>&1 || return 1
  local spec
  while IFS= read -r spec; do
    if uv pip install --quiet --reinstall --python "$venv/bin/python" "$spec" >/dev/null 2>&1; then
      return 0
    fi
  done < <(specs)
  return 1
}

install_with_venv() {
  command -v python3 >/dev/null 2>&1 || return 1
  export GIT_TERMINAL_PROMPT=0
  [ -x "$venv/bin/pip" ] || python3 -m venv "$venv" >/dev/null 2>&1 || return 1
  [ -x "$venv/bin/pip" ] || return 1
  local spec
  while IFS= read -r spec; do
    if "$venv/bin/pip" install --quiet --force-reinstall "$spec" >/dev/null 2>&1; then
      return 0
    fi
  done < <(specs)
  return 1
}

case "${1:-}" in
  shellcheck|htmltest|hugo-latest)
    if locate_binary "$1"; then exit 0; fi
    if [ "${2:-}" = fetch ] && fetch_binary "$1"; then
      ( cd "$BIN" && pwd -P )
      exit 0
    fi
    printf '%s\n' "$1 is not installed. ./c setup fetches it into $BIN." >&2
    exit 3
    ;;
  stylelint|eslint|pa11y-ci|lhci|playwright)
    if locate_node "$1"; then exit 0; fi
    if [ "${2:-}" = fetch ]; then
      if ! command -v npm >/dev/null 2>&1; then
        printf '%s\n' "npm is not installed, and $1 arrives through it. Node is yours to install." >&2
        exit 3
      fi
      case "$1" in
        stylelint) pkgs="stylelint stylelint-config-standard" ;;
        eslint) pkgs="eslint" ;;
        pa11y-ci) pkgs="pa11y-ci" ;;
        lhci) pkgs="@lhci/cli" ;;
        playwright) pkgs="playwright pixelmatch pngjs" ;;
      esac
      # Installed under tools/, against a package.json that grows by
      # tool. Without one, npm rebuilds node_modules to hold only the
      # package it was last given, and every earlier tool goes.
      # shellcheck disable=SC2086
      npm install --prefix tools --save --silent $pkgs >/dev/null 2>&1
      # The browser is what the tool is for. Fetching the one
      # without the other would answer ok and then skip.
      if [ "$1" = playwright ] && [ -x tools/node_modules/.bin/playwright ]; then
        tools/node_modules/.bin/playwright install chromium >/dev/null 2>&1
      fi
      if locate_node "$1"; then exit 0; fi
    fi
    printf '%s\n' "$1 is not installed. ./c setup fetches it." >&2
    exit 3
    ;;
  html5validator)
    if command -v html5validator >/dev/null 2>&1; then
      dirname "$(command -v html5validator)"
      exit 0
    fi
    if [ -x "$venv/bin/html5validator" ]; then
      ( cd "$venv/bin" && pwd -P )
      exit 0
    fi
    if [ "${2:-}" = fetch ] && install_from_pypi html5validator; then
      ( cd "$venv/bin" && pwd -P )
      exit 0
    fi
    printf '%s\n' "html5validator is not installed. ./c setup fetches it. It drives Java." >&2
    exit 3
    ;;
  *)
    printf '%s\n' "usage: tools/scripts/tools.sh <tool> [fetch]" >&2
    printf '%s\n' "tools: shellcheck htmltest hugo-latest stylelint eslint pa11y-ci lhci playwright html5validator" >&2
    exit 2
    ;;
esac
