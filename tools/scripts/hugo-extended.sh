#!/usr/bin/env bash
# Exit 0 when the installed Hugo is the extended build. The fixture
# processes images, so the plain build cannot run it.
set -euo pipefail

hugo version | grep -q 'extended'
