#!/usr/bin/env bash
# The file list and the skeleton, as one gate.
# reads: conformance
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
conformance/scripts/conform.sh
