#!/usr/bin/env bash
# Generate the theme from the installed Hugo, once.
#
# The template holds no theme. A project starts from the scaffold of
# whichever Hugo is installed on the day it starts. It is never a copy
# frozen when the template was written.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

# The name a person gives is the display name. It goes into theme.toml as
# is. Hugo, hugo mod and themes.gohugo.io each want a slug of lowercase
# letters, digits and hyphens. The slug becomes a directory, a module path
# and a URL. It is derived here, once, and never asked for.
NAME="${1:-}"
OWNER="${2:-}"
REPO="${3:-}"
[ -n "$NAME" ] || { echo "usage: scripts/bootstrap.sh NAME [OWNER] [REPO]" >&2; exit 2; }
SLUG="$(printf '%s' "$NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//')"
[ -n "$SLUG" ] || { printf '%s\n' "no letters or digits in name: $NAME" >&2; exit 2; }
[ "$SLUG" = "$NAME" ] || printf '%s\n' "theme slug: $SLUG (from \"$NAME\")"

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
hugo new theme "$SLUG" --themesDir "$tmp" >/dev/null || fail "hugo new theme failed."
src="$tmp/$SLUG"
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
#
#    The owner and the repository are given, or read from the remote,
#    or left as placeholders. Whoever calls knows them. The workflow
#    has them in its environment, and a clone has them in its remote.
#
#    A placeholder left in theme.toml is a URL going nowhere. The
#    release gate then fails on it later rather than sooner.
#
#    The repository name is not the slug. One may be called My-Theme
#    while Hugo knows it as my-theme, and the URL has to name the
#    repository. A module path is case sensitive, and module.sh reads
#    that path out of homepage.
year="$(date +%Y)"
if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  remote="$(git config --get remote.origin.url 2>/dev/null || true)"
  remote="${remote%.git}"
  [ -n "$OWNER" ] || \
    OWNER="$(printf '%s' "$remote" | sed -n 's|.*[:/]\([^/:]*\)/[^/]*$|\1|p')"
  [ -n "$REPO" ] || \
    REPO="$(printf '%s' "$remote" | sed -n 's|.*/\([^/]*\)$|\1|p')"
fi
[ -n "$OWNER" ] || OWNER=OWNER
[ -n "$REPO" ] || REPO="$SLUG"
if [ "$OWNER" = OWNER ]; then
  printf '%s\n' "no owner given or found, so theme.toml keeps the placeholder"
fi

render() {
  sed -e "s|{{NAME}}|$NAME|g" -e "s|{{SLUG}}|$SLUG|g" -e "s|{{OWNER}}|$OWNER|g" \
      -e "s|{{REPO}}|$REPO|g" \
      -e "s|{{HUGO_VERSION}}|$version|g" -e "s|{{YEAR}}|$year|g" "$1"
}
render templates/theme.toml.tmpl > theme.toml
render templates/README.md.tmpl > README.md
# The template's own changelog is the template's history, not this
# theme's. A project inheriting it would ship somebody else's releases.
render templates/CHANGELOG.md.tmpl > CHANGELOG.md
mkdir -p i18n data assets static archetypes

# 6. Pin the floor to the Hugo that generated this.
if [ -f hugo.toml ]; then
  tmpfile="$(mktemp "$PWD/.hugo-toml-XXXXXX")"
  # The floor is the Hugo that generated this. The extended build is
  # required, because the fixture processes images. The scaffold says
  # otherwise, and a downloader would believe it.
  sed -e "s|^\( *min *= *\).*|\1'$version'|" \
      -e "s|^\( *extended *= *\).*|\1true|" hugo.toml > "$tmpfile"
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
scripts/install-imports.sh
scripts/install-highlight.sh
scripts/install-a11y-css.sh

# 8. Install the feature mechanism into the generated layouts.
scripts/install-features.sh
scripts/install-top.sh

# 9. The contract is generated from the templates, and the static gate
#    compares the committed file against a fresh one. Without this the
#    first check fails on a file that never existed.
scripts/docs.sh

# The one-shot pieces go, now that they have run. Keeping them leaves
# a project with a README template that overwrites its own README.
# The bootstrap workflow can never fire again either.
rm -f templates/README.md.tmpl templates/theme.toml.tmpl templates/CHANGELOG.md.tmpl
rm -f .github/workflows/bootstrap.yml
rm -f BOOTSTRAP

# 10. Prove the pair before handing back.
./c conform || fail "the fresh scaffold does not conform. The suite is wrong, not the theme."

cat <<EOF

Generated $NAME ($SLUG) from Hugo $version.

  git add -A && git commit -m "Generate theme scaffold from Hugo $version"

EOF
