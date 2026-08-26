#!/usr/bin/env bash
# Fetch a pinned tool into .tools/ when it is not already on PATH.
#
# Usage: scripts/tools.sh writing-lint
# Prints the directory holding the entry points, or exits 3.
#
# uv is preferred, because it carries its own Python and needs no
# ensurepip. A Debian box without python3-venv cannot build a virtual
# environment with pip in it. That is the common case handled here.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

WRITING_LINT_TAG=v1.0.2
WRITING_LINT_REPO=FoundingFuture/writing-lint

venv=.tools/venv

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
  writing-lint)
    want="${WRITING_LINT_TAG#v}"

    # A copy already on PATH is used only when it is the pinned version.
    #
    # Taking whichever one happened to be installed made the pin a note
    # rather than a pin. A runner one release behind then read the rules
    # of that release, while claiming to read these.
    if command -v check-web-content >/dev/null 2>&1; then
      if [ "$(version_of "$(command -v check-web-content)")" = "$want" ]; then
        dirname "$(command -v check-web-content)"
        exit 0
      fi
    fi

    # The same test on the fetched copy. Without it a bumped pin never
    # reached a checkout that had already fetched the older one.
    if [ "$(version_of "$venv/bin/check-web-content")" = "$want" ]; then
      ( cd "$venv/bin" && pwd -P )
      exit 0
    fi

    if install_with_uv || install_with_venv; then
      got="$(version_of "$venv/bin/check-web-content")"
      if [ "$got" != "$want" ]; then
        printf '%s\n' "asked for writing-lint $want and got ${got:-nothing}." >&2
        exit 3
      fi
      ( cd "$venv/bin" && pwd -P )
      exit 0
    fi
    printf '%s\n' "writing-lint ${WRITING_LINT_TAG} could not be installed." >&2
    printf '%s\n' "Needs uv or python3-venv, and access to ${WRITING_LINT_REPO}." >&2
    printf '%s\n' "For a private fork, set GH_TOKEN or give the runner a key." >&2
    exit 3
    ;;
  *)
    echo "usage: scripts/tools.sh writing-lint" >&2
    exit 2
    ;;
esac
