#!/usr/bin/env bash
# Every page resolves without JavaScript. A menu that needs a script
# is a menu a crawler cannot follow and a reader may never see.
# reads: tools/conformance/public/ours
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"


source_dir=tools/conformance/public/ours
target=tools/conformance/public/nojs
[ -d "$source_dir" ] || { echo "SKIP nojs: no build at $source_dir"; exit 3; }

rm -rf "$target"
cp -R "$source_dir" "$target"
"$PY_BIN" - "$target" <<'PY'
import os, re, sys
root = sys.argv[1]
strip = re.compile(r"<script\b.*?</script>|<script\b[^>]*/?>", re.DOTALL | re.IGNORECASE)
for folder, dirs, files in os.walk(root):
    for name in files:
        if not name.endswith(".html"):
            continue
        path = os.path.join(folder, name)
        with open(path, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(strip.sub("", text))
PY

status=0
tools/scripts/check/head.sh "$target" || status=1
bin="$(tools/scripts/tools.sh htmltest 2>/dev/null)" && PATH="$bin:$PATH"
if command -v htmltest >/dev/null 2>&1; then
  htmltest -c tools/scripts/check/htmltest.yml "$target" || status=1
fi
exit $status
