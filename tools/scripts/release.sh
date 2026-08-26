#!/usr/bin/env bash
# Run the release gate, refresh the snapshots, tag, and push.
#
# The snapshots are committed to the tag. The next branch is then
# compared against what was released, rather than against whatever
# happened to be built last.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

version="${1:-}"
[ -n "$version" ] || { echo "usage: ./c release v=1.2.0" >&2; exit 2; }
case "$version" in v*) tag="$version" ;; *) tag="v$version" ;; esac

[ -z "$(git status --porcelain)" ] || { echo "the working tree is dirty." >&2; exit 1; }
git rev-parse "$tag" >/dev/null 2>&1 && { echo "$tag already exists." >&2; exit 1; }

RELEASE_TAG="$tag" export RELEASE_TAG
tools/scripts/check/run.sh static || exit 1
tools/scripts/check/run.sh build  || exit 1
tools/scripts/check/run.sh output || exit 1
tools/scripts/check/run.sh release || exit 1

./c snapshot
git add tools/conformance/snapshots
if ! git diff --cached --quiet; then
  git commit -q -m "Refresh the conformance snapshots for $tag"
fi

body="$(awk -v want="## $tag," '
  index($0, want) == 1 { found = 1; next }
  found && /^## / { exit }
  found { print }
' CHANGELOG.md)"

git tag -a "$tag" -m "$tag

$body"
git push origin HEAD
git push origin "$tag"
printf '%s\n' "tagged $tag and pushed"
