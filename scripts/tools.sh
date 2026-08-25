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
cd "$(dirname "$0")/.."

WRITING_LINT_TAG=v1.0.1
WRITING_LINT_REPO=FoundingFuture/writing-lint

venv=.tools/venv

specs() {
  # The repository is private. ssh first, by whichever host name resolves,
  # then a token for CI, which has no key.
  printf '%s\n' "git+ssh://git@github.com/${WRITING_LINT_REPO}@${WRITING_LINT_TAG}"
  printf '%s\n' "git+ssh://git@github-ff/${WRITING_LINT_REPO}@${WRITING_LINT_TAG}"
  if [ -n "${GH_TOKEN:-}" ]; then
    printf '%s\n' "git+https://${GH_TOKEN}@github.com/${WRITING_LINT_REPO}@${WRITING_LINT_TAG}"
  fi
}

install_with_uv() {
  command -v uv >/dev/null 2>&1 || return 1
  [ -x "$venv/bin/python" ] || uv venv --quiet "$venv" >/dev/null 2>&1 || return 1
  local spec
  while IFS= read -r spec; do
    if uv pip install --quiet --python "$venv/bin/python" "$spec" >/dev/null 2>&1; then
      return 0
    fi
  done < <(specs)
  return 1
}

install_with_venv() {
  command -v python3 >/dev/null 2>&1 || return 1
  [ -x "$venv/bin/pip" ] || python3 -m venv "$venv" >/dev/null 2>&1 || return 1
  [ -x "$venv/bin/pip" ] || return 1
  local spec
  while IFS= read -r spec; do
    if "$venv/bin/pip" install --quiet "$spec" >/dev/null 2>&1; then
      return 0
    fi
  done < <(specs)
  return 1
}

case "${1:-}" in
  writing-lint)
    if command -v check-web-content >/dev/null 2>&1; then
      dirname "$(command -v check-web-content)"
      exit 0
    fi
    if [ -x "$venv/bin/check-web-content" ]; then
      ( cd "$venv/bin" && pwd -P )
      exit 0
    fi
    if install_with_uv || install_with_venv; then
      ( cd "$venv/bin" && pwd -P )
      exit 0
    fi
    printf '%s\n' "writing-lint ${WRITING_LINT_TAG} could not be installed." >&2
    printf '%s\n' "Needs uv or python3-venv, and access to ${WRITING_LINT_REPO}." >&2
    exit 3
    ;;
  *)
    echo "usage: scripts/tools.sh writing-lint" >&2
    exit 2
    ;;
esac
