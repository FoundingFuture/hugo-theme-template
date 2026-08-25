#!/usr/bin/env bash
# The file list and the skeleton, as one gate.
set -uo pipefail
cd "$(dirname "$0")/../.."
conformance/scripts/conform.sh
