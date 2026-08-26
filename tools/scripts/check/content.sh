#!/usr/bin/env bash
# The content checker over the fixture, and the docs checker over the
# markdown the repository itself carries.
# reads: tools/conformance/content/kitchen-sink README.md CHANGELOG.md docs contract.toml
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

bin="$(tools/scripts/tools.sh writing-lint 2>/dev/null)" || {
  echo "SKIP content: writing-lint not installed"; exit 3; }
[ -x "$bin/check-web-content" ] || { echo "SKIP content: check-web-content not on PATH"; exit 3; }

status=0
contract=""
[ -f contract.toml ] && contract="--contract contract.toml"
# shellcheck disable=SC2086
"$bin/check-web-content" $contract tools/conformance/content/kitchen-sink || status=1

docs_targets=""
for path in README.md CHANGELOG.md docs; do
  [ -e "$path" ] && docs_targets="$docs_targets $path"
done
if [ -n "$docs_targets" ]; then
  # shellcheck disable=SC2086
  "$bin/check-docs" $docs_targets || status=1
fi
exit $status
