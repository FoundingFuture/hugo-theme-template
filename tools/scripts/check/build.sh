#!/usr/bin/env bash
# Four builds. The two the fixture compares, one minified, and one under
# a subpath, which is where an absolute path breaks.
# reads: tools/conformance
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

tools/scripts/reference.sh || { echo "conformance:1: could not generate the reference."; exit 1; }
status=0
run() {
  local label="$1" config="$2" dest="$3"
  shift 3
  # The redirect happens inside the subshell. The file lands beside the
  # build, rather than at the repository root where nothing read it.
  if ! ( cd tools/conformance && hugo --config "$config" -d "public/$dest" \
      --panicOnWarning --printPathWarnings --printUnusedTemplates \
      --printI18nWarnings --logLevel warn --gc "$@" >/dev/null 2>.build-err ); then
    printf '%s\n' "conformance:1: the $label build failed."
    [ -f tools/conformance/.build-err ] && sed 's/^/    /' tools/conformance/.build-err | head -12
    status=1
  fi
  rm -f tools/conformance/.build-err
}
tools/scripts/configs.sh >/dev/null || { echo "build: the configs could not be written."; exit 1; }

run "reference" hugo.toml,config/hugo/hugo.toml hugo
run "theme" hugo.toml,config/ours/hugo.toml ours
run "minified" hugo.toml,config/ours/hugo.toml minified --minify
run "subpath" hugo.toml,config/ours/hugo.toml subpath --baseURL https://example.org/sub/path/
exit $status
