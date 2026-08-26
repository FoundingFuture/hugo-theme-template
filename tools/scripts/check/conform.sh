#!/usr/bin/env bash
# The file list and the skeleton, as one gate.
# reads: tools/conformance
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1
tools/conformance/scripts/conform.sh
