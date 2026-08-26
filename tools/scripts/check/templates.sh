#!/usr/bin/env bash
# Every file under layouts/ is reachable. An unused template is either
# dead weight or a page that never renders, and both are faults.
# reads: layouts tools/conformance
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

tools/scripts/configs.sh >/dev/null || { echo "templates: the configs could not be written."; exit 1; }

out="$(cd tools/conformance && hugo --config hugo.toml,config/ours/hugo.toml \
  -d public/unused --printUnusedTemplates --logLevel warn --gc 2>&1)" || {
    printf '%s\n' "$out" | sed -n 's/^/layouts:1: /p' | head -20
    exit 1
  }
if printf '%s' "$out" | grep -q 'is unused'; then
  printf '%s' "$out" | grep 'is unused' | sed 's/^WARN *//' \
    | sed 's|^Template \(/[^ ]*\) is unused.*|layouts\1:1: template is unused.|'
  exit 1
fi
exit 0
