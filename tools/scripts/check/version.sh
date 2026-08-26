#!/usr/bin/env bash
# The tag moves forward, and the theme does not claim a Hugo newer than
# the one it was built against.
# reads: theme.toml .hugo-version
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

status=0
pinned="$(cat .hugo-version 2>/dev/null || true)"
declared="$(sed -n 's/^ *min_version *= *"\([^"]*\)".*/\1/p' theme.toml 2>/dev/null | head -1)"
if [ -n "$pinned" ] && [ -n "$declared" ]; then
  lowest="$(printf '%s\n%s\n' "$declared" "$pinned" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)"
  if [ "$lowest" != "$declared" ]; then
    printf '%s\n' "theme.toml:1: min_version $declared is newer than .hugo-version $pinned."
    status=1
  fi
fi

tag="${1:-${RELEASE_TAG:-}}"
if [ -n "$tag" ]; then
  previous="$(git tag --sort=-v:refname | grep -v "^${tag}\$" | head -1 || true)"
  if [ -n "$previous" ]; then
    newest="$(printf '%s\n%s\n' "${tag#v}" "${previous#v}" \
      | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
    if [ "$newest" != "${tag#v}" ]; then
      printf '%s\n' "$tag:1: is not greater than the previous tag $previous."
      status=1
    fi
  fi
fi
exit $status
