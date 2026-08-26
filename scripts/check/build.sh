#!/usr/bin/env bash
# Four builds. The two the fixture compares, one minified, and one under
# a subpath, which is where an absolute path breaks.
set -uo pipefail
cd "$(dirname "$0")/../.."

scripts/reference.sh || { echo "conformance:1: could not generate the reference."; exit 1; }
status=0
run() {
  local label="$1" config="$2" dest="$3"
  shift 3
  # The redirect happens inside the subshell, so the file lands beside
  # the build rather than at the repository root, where nothing read it.
  if ! ( cd conformance && hugo --config "$config" -d "public/$dest" \
      --panicOnWarning --printPathWarnings --printUnusedTemplates \
      --printI18nWarnings --logLevel warn --gc "$@" >/dev/null 2>.build-err ); then
    printf '%s\n' "conformance:1: the $label build failed."
    [ -f conformance/.build-err ] && sed 's/^/    /' conformance/.build-err | head -12
    status=1
  fi
  rm -f conformance/.build-err
}
run "reference" hugo.toml,config/hugo/hugo.toml hugo
run "theme" hugo.toml,config/ours/hugo.toml ours
run "minified" hugo.toml,config/ours/hugo.toml minified --minify
run "subpath" hugo.toml,config/ours/hugo.toml subpath --baseURL https://example.org/sub/path/
exit $status
