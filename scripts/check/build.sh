#!/usr/bin/env bash
# Four builds. The two the fixture compares, one minified, and one under
# a subpath, which is where an absolute path breaks.
set -uo pipefail
cd "$(dirname "$0")/../.."

scripts/reference.sh || { echo "conformance:1: could not generate the reference."; exit 1; }
status=0
run() {
  local label="$1" dest="$2"
  shift 2
  if ! ( cd conformance && hugo --config hugo.toml,config/ours/hugo.toml -d "public/$dest" \
      --panicOnWarning --printPathWarnings --printUnusedTemplates \
      --printI18nWarnings --logLevel warn --gc "$@" ) >/dev/null 2>.build-err; then
    printf '%s\n' "conformance:1: $label build failed."
    sed 's/^/    /' conformance/.build-err | head -12
    status=1
  fi
  rm -f conformance/.build-err
}
run "reference" hugo
run "theme" ours
run "minified" minified --minify
run "subpath" subpath --baseURL https://example.org/sub/path/
exit $status
