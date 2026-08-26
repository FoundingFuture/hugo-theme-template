#!/usr/bin/env bash
# A feature is a manifest, a partial, a stylesheet, its words, and a
# fixture page. This writes all of them, because the static gate fails
# until every one exists. That is the only way a feature enters a theme.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

# Git Bash has python and not python3, and the manifests need a reader
# that parses TOML. tools/scripts/python.sh answers both questions.
PY_BIN="$(tools/scripts/python.sh 2>/dev/null || echo python3)"


partials=layouts/_partials
[ -d "$partials" ] || partials=layouts/partials

action="${1:-list}"
name="${2:-}"

manifest_path() { printf 'data/features/%s.toml\n' "$1"; }

cmd_list() {
  local python found=0 base
  python="$(tools/scripts/python.sh 2>/dev/null || echo python3)"
  printf '%-18s %-10s %-18s %-8s %s\n' NAME STATE SLOT DEFAULT LEVEL
  for file in data/features/*.toml; do
    [ -e "$file" ] || continue
    found=1
    "$python" tools/scripts/read-manifest.py "$file"
  done
  for file in tools/templates/feature/manifests/*.toml; do
    [ -e "$file" ] || continue
    base="$(basename "$file" .toml)"
    [ -e "data/features/$base.toml" ] && continue
    found=1
    printf '%-18s %-10s %-18s %-8s %s\n' "$base" available "" "" 'add with ./c feature add'
  done
  [ "$found" -eq 1 ] || echo "no features"
}

cmd_new() {
  [ -n "$name" ] || { echo "usage: ./c feature new name=<slug>" >&2; exit 2; }
  local manifest partial sheet page camel
  manifest="$(manifest_path "$name")"
  partial="$partials/features/$name.html"
  sheet="assets/css/features/$name.css"
  page="tools/conformance/content/kitchen-sink/features/$name.md"
  [ -e "$manifest" ] && { echo "$manifest already exists" >&2; exit 1; }
  camel="$(printf '%s' "$name" | awk -F- '{printf "%s", $1; for(i=2;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}')"

  mkdir -p "$(dirname "$manifest")" "$(dirname "$partial")" \
           "$(dirname "$sheet")" "$(dirname "$page")"
  sed -e "s|{{NAME}}|$name|g" -e "s|{{KEY}}|$camel|g" \
    tools/templates/feature/manifest.toml.tmpl > "$manifest"
  sed -e "s|{{NAME}}|$name|g" -e "s|{{KEY}}|$camel|g" \
    tools/templates/feature/partial.html.tmpl > "$partial"
  sed -e "s|{{NAME}}|$name|g" tools/templates/feature/style.css.tmpl > "$sheet"
  sed -e "s|{{NAME}}|$name|g" -e "s|{{KEY}}|$camel|g" \
    tools/templates/feature/page.md.tmpl > "$page"
  if ! grep -q "^\[$camel\]" i18n/en.toml 2>/dev/null; then
    printf '\n[%s]\nother = "%s"\n' "$camel" "$name" >> i18n/en.toml
  fi
  printf '%s\n' "wrote $manifest" "wrote $partial" "wrote $sheet" "wrote $page"
  printf '%s\n' "The partial renders a placeholder. The static gate fails until it renders the feature."
}

switch() {
  local value="$1" config=tools/conformance/hugo.toml
  [ -n "$name" ] || { echo "usage: ./c feature $action name=<slug>" >&2; exit 2; }
  [ -e "$(manifest_path "$name")" ] || { echo "no feature named $name" >&2; exit 1; }
  "$PY_BIN" - "$config" "$name" "$value" <<'PY'
import re, sys
path, name, value = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as handle:
    text = handle.read()
line = "  %s = %s" % (name, value)
if "[params.features]" not in text:
    text = text.rstrip() + "\n\n[params.features]\n" + line + "\n"
else:
    pattern = re.compile(r"^(\s*%s\s*=\s*).*$" % re.escape(name), re.MULTILINE)
    if pattern.search(text):
        text = pattern.sub(lambda m: "%s%s" % (m.group(1), value), text)
    else:
        text = text.replace("[params.features]", "[params.features]\n" + line, 1)
with open(path, "w", encoding="utf-8") as handle:
    handle.write(text)
print("%s = %s in %s" % (name, value, path))
PY
}

# Install one of the features the template ships, whole.
cmd_add() {
  [ -n "$name" ] || { echo "usage: ./c feature add name=<slug>" >&2; exit 2; }
  local manifest="tools/templates/feature/manifests/$name.toml"
  local partial="tools/templates/feature/partials/$name.html"
  local sheet="tools/templates/feature/css/$name.css"
  [ -f "$manifest" ] || { echo "the template ships no feature named $name" >&2; exit 1; }
  [ -e "data/features/$name.toml" ] && { echo "$name is already installed" >&2; exit 1; }

  mkdir -p data/features "$partials/features" assets/css/features \
           tools/conformance/content/kitchen-sink/features
  cp "$manifest" "data/features/$name.toml"
  cp "$partial" "$partials/features/$name.html"
  [ -f "$sheet" ] && cp "$sheet" "assets/css/features/$name.css"

  local camel
  camel="$(printf '%s' "$name" | awk -F- '{printf "%s", $1; for(i=2;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}')"
  sed -e "s|{{NAME}}|$name|g" -e "s|{{KEY}}|$camel|g" \
    tools/templates/feature/page.md.tmpl > "tools/conformance/content/kitchen-sink/features/$name.md"
  if ! grep -q "^\[$camel\]" i18n/en.toml 2>/dev/null; then
    printf '\n[%s]\nother = "%s"\n' "$camel" "$name" >> i18n/en.toml
  fi
  printf '%s\n' "installed $name. Run ./c docs, then ./c conform."
}

# The features the template ships and has not installed.
cmd_available() {
  local found=0 base
  for file in tools/templates/feature/manifests/*.toml; do
    [ -e "$file" ] || continue
    base="$(basename "$file" .toml)"
    [ -e "data/features/$base.toml" ] && continue
    found=1
    printf '%s\n' "$base"
  done
  [ "$found" -eq 1 ] || echo "every shipped feature is installed"
}

case "$action" in
  list) cmd_list ;;
  add) cmd_add ;;
  available) cmd_available ;;
  new)  cmd_new ;;
  on)   switch true ;;
  off)  switch false ;;
  *) printf '%s\n' "unknown action: $action" >&2; exit 2 ;;
esac
