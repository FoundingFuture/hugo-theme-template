#!/usr/bin/env bash
# The contract file and the front matter document are both generated. A
# stale one means the documentation and the templates disagree, and the
# documentation is what a user reads.
# reads: layouts data contract.toml docs/front-matter.md
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

fresh="$(mktemp -d tools/.contract-fresh.XXXXXX)" || exit 1
trap 'rm -rf "$fresh"' EXIT

tools/scripts/docs.sh --into "$fresh" 2>/dev/null || {
  echo "contract.toml:1: could not regenerate the contract."
  exit 1
}

status=0
for name in contract.toml docs/front-matter.md; do
  if ! diff -q "$name" "$fresh/$name" >/dev/null 2>&1; then
    echo "$name:1: stale. Run ./c docs."
    diff -u "$name" "$fresh/$name" | head -30
    status=1
  fi
done
exit $status
