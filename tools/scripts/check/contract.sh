#!/usr/bin/env bash
# The contract file is generated. A stale one means the documentation
# and the templates disagree, and the documentation is what a user reads.
# reads: layouts data contract.toml
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

tools/scripts/docs.sh --stdout > .contract-fresh.toml 2>/dev/null || {
  rm -f .contract-fresh.toml
  echo "contract.toml:1: could not regenerate the contract."
  exit 1
}
status=0
if ! diff -q contract.toml .contract-fresh.toml >/dev/null 2>&1; then
  echo "contract.toml:1: stale. Run ./c docs."
  diff -u contract.toml .contract-fresh.toml | head -30
  status=1
fi
rm -f .contract-fresh.toml
exit $status
