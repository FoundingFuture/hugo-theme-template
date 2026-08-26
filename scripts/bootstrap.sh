#!/usr/bin/env bash
# Generate the theme from the installed Hugo, once.
#
# The template holds no theme. A project starts from the scaffold of
# whichever Hugo is installed on the day it starts. It is never a copy
# frozen when the template was written.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${1:-}"
[ -n "$NAME" ] || { echo "usage: scripts/bootstrap.sh NAME" >&2; exit 2; }
case "$NAME" in
  *[!a-z0-9-]* | -* | *- )
    printf '%s\n' "name must be lowercase letters, digits and hyphens: $NAME" >&2
    exit 2 ;;
esac

# 0.146 introduced this layout, but the fixture uses languages.*.label,
# which replaced languageName in 0.158. --panicOnWarning turns the
# deprecation into a build failure, so 0.158 is the real floor.
MIN_VERSION=0.158.0

fail() { printf '%s\n' "$1" >&2; exit 1; }

# 1. Hugo must be present, extended, and recent enough for this layout.
command -v hugo >/dev/null 2>&1 || fail "hugo is not on PATH."
version="$(scripts/hugo-version.sh)"
scripts/hugo-extended.sh || fail "hugo $version is not the extended build. The fixture processes images."
lowest="$(printf '%s\n%s\n' "$MIN_VERSION" "$version" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)"
[ "$lowest" = "$MIN_VERSION" ] || fail "hugo $version is older than $MIN_VERSION, which the conformance fixture needs."

# 2. Bootstrap is one-shot.
[ -d layouts ] && fail "layouts/ already exists. This project is bootstrapped."

# 3. Generate into a temporary directory, so a failure leaves nothing behind.
# Inside the repository, not /tmp. A snap-confined Hugo has its own
# private /tmp, which the calling shell cannot see. A move across
# filesystems is also slower than a rename.
tmp="$(mktemp -d "$PWD/.bootstrap-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
hugo new theme "$NAME" --themesDir "$tmp" >/dev/null || fail "hugo new theme failed."
src="$tmp/$NAME"
[ -d "$src" ] || fail "hugo wrote nothing to $src."

# 4. Move the scaffold to the root, resolving what the two sides both own.
#    The sample content becomes a fixture. A theme repository carries no
#    content of its own.
mkdir -p conformance/content/scaffold
if [ -d "$src/content" ]; then
  cp -R "$src/content/." conformance/content/scaffold/
  rm -rf "$src/content"
fi
rm -f "$src/LICENSE" "$src/README.md"
for entry in "$src"/* "$src"/.[!.]*; do
  [ -e "$entry" ] || continue
  base="$(basename "$entry")"
  rm -rf "./$base"
  mv "$entry" "./$base"
done

# 5. Write what Hugo does not generate.
year="$(date +%Y)"
sed -e "s|{{NAME}}|$NAME|g" -e "s|{{HUGO_VERSION}}|$version|g" -e "s|{{YEAR}}|$year|g" \
  templates/theme.toml.tmpl > theme.toml
sed -e "s|{{NAME}}|$NAME|g" -e "s|{{HUGO_VERSION}}|$version|g" -e "s|{{YEAR}}|$year|g" \
  templates/README.md.tmpl > README.md
mkdir -p i18n data assets static archetypes

# 6. Pin the floor to the Hugo that generated this.
if [ -f hugo.toml ]; then
  tmpfile="$(mktemp "$PWD/.hugo-toml-XXXXXX")"
  sed "s|^\( *min *= *\).*|\1'$version'|" hugo.toml > "$tmpfile"
  mv "$tmpfile" hugo.toml
fi
printf '%s\n' "$version" > .hugo-version

# 7. The scaffold ships English inside its markup. A theme that does
#    that is broken for whoever installs it. The words gate says so, so
#    the strings move into i18n before the first check runs.
scripts/internationalise.sh
scripts/install-head.sh
scripts/install-links.sh
scripts/install-css.sh

# 8. Install the feature mechanism into the generated layouts.
scripts/install-features.sh

# 9. The contract is generated from the templates, and the static gate
#    compares the committed file against a fresh one. Without this the
#    first check fails on a file that never existed.
scripts/docs.sh

rm -f BOOTSTRAP

# 10. Prove the pair before handing back.
./c conform || fail "the fresh scaffold does not conform. The suite is wrong, not the theme."

cat <<EOF

Generated $NAME from Hugo $version.

  git add -A && git commit -m "Generate theme scaffold from Hugo $version"

EOF
