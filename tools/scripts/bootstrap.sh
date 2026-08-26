#!/usr/bin/env bash
# Generate the theme from the installed Hugo, once.
#
# The template holds no theme. A project starts from the scaffold of
# whichever Hugo version is installed on the day it starts. It is not a copy
# frozen when the template was written.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

# The name a person gives is the display name. It goes into theme.toml as
# is. Hugo, hugo mod and themes.gohugo.io each want a slug of lowercase
# letters, digits and hyphens. The slug becomes a directory, a module path
# and a URL. It is derived here, once, and never asked for.
NAME="${1:-}"
OWNER="${2:-}"
REPO="${3:-}"
[ -n "$NAME" ] || { echo "usage: tools/scripts/bootstrap.sh NAME [OWNER] [REPO]" >&2; exit 2; }
SLUG="$(printf '%s' "$NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//')"
[ -n "$SLUG" ] || { printf '%s\n' "no letters or digits in name: $NAME" >&2; exit 2; }
[ "$SLUG" = "$NAME" ] || printf '%s\n' "theme slug: $SLUG (from \"$NAME\")"

# 0.146 introduced this layout, but the fixture uses languages.*.label,
# which replaced languageName in 0.158. --panicOnWarning turns the
# deprecation into a build failure, so 0.158 is the real floor.
MIN_VERSION=0.158.0

# The template's own repository name. A clone or a fork of the template
# has it as the last part of the remote URL. A repository made with the
# "Use this template" button has its own name there.
TEMPLATE=hugo-theme-template

fail() { printf '%s\n' "$1" >&2; exit 1; }

# 1. Hugo must be present, extended, and recent enough for this layout.
command -v hugo >/dev/null 2>&1 || fail "hugo is not on PATH."
version="$(tools/scripts/hugo-version.sh)"
tools/scripts/hugo-extended.sh || fail "hugo $version is not the extended build. The fixture processes images."
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
mkdir -p tools/conformance/content/scaffold
if [ -d "$src/content" ]; then
  cp -R "$src/content/." tools/conformance/content/scaffold/
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
#    has them in its environment, and a repository made with the button
#    has them in its remote.
#
#    A clone of the template has the template in its remote. That names
#    the template, not the project, so nothing is read from it. The
#    clone case is finished in step 11.
#
#    A placeholder left in theme.toml is a URL going nowhere. The
#    release gate then fails on it later rather than sooner.
#
#    The repository name is not the slug. One may be called My-Theme
#    while Hugo knows it as my-theme, and the URL has to name the
#    repository. A module path is case sensitive, and module.sh reads
#    that path out of homepage.
year="$(date +%Y)"
origin="$(git config --get remote.origin.url 2>/dev/null || true)"
remote="${origin%.git}"
remote="${remote%/}"
cloned=no
case "$remote" in
  */"$TEMPLATE"|*:"$TEMPLATE") cloned=yes ;;
esac
if [ "$cloned" = no ] && { [ -z "$OWNER" ] || [ -z "$REPO" ]; }; then
  [ -n "$OWNER" ] || \
    OWNER="$(printf '%s' "$remote" | sed -n 's|.*[:/]\([^/:]*\)/[^/]*$|\1|p')"
  [ -n "$REPO" ] || \
    REPO="$(printf '%s' "$remote" | sed -n 's|.*/\([^/]*\)$|\1|p')"
fi
[ -n "$OWNER" ] || OWNER=OWNER
[ -n "$REPO" ] || REPO="$SLUG"
if [ "$OWNER" = OWNER ] && [ "$cloned" = yes ]; then
  printf '%s\n' "cloned from the template, and no owner given, so theme.toml keeps the placeholder"
elif [ "$OWNER" = OWNER ]; then
  printf '%s\n' "no owner given or found, so theme.toml keeps the placeholder"
fi

render() {
  sed -e "s|{{NAME}}|$NAME|g" -e "s|{{SLUG}}|$SLUG|g" -e "s|{{OWNER}}|$OWNER|g" \
      -e "s|{{REPO}}|$REPO|g" \
      -e "s|{{HUGO_VERSION}}|$version|g" -e "s|{{YEAR}}|$year|g" "$1"
}
render tools/templates/theme.toml.tmpl > theme.toml
render tools/templates/README.md.tmpl > README.md
# The template's own changelog is the template's history, not this
# theme's. A project inheriting it would ship somebody else's releases.
render tools/templates/CHANGELOG.md.tmpl > CHANGELOG.md
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

# 6b. A theme decides none of these. The scaffold's config carries a
#     baseURL, a title and a menu. Hugo merges a theme's menus into
#     every site that adopts it, then drops an entry whose
#     page is missing. A downloader's navigation would depend on the
#     sections they happen to have. What stays is what the theme owns:
#     the Hugo floor, the highlighting it styles, and its features.
if [ -f hugo.toml ]; then
  tmpfile="$(mktemp "$PWD/.hugo-toml-XXXXXX")"
  awk '
    /^\[\[?menus/            { skip = 1; next }
    /^\[/ && $0 !~ /^\[\[?menus/ { skip = 0 }
    skip                     { next }
    /^ *baseURL *=/          { next }
    /^ *title *=/            { next }
    /^ *locale *=/           { next }
    { print }
  ' hugo.toml > "$tmpfile"
  mv "$tmpfile" hugo.toml
fi

# 7. The scaffold ships English inside its markup. A theme that does
#    that is broken for whoever installs it. The words gate says so, so
#    the strings move into i18n before the first check runs.
tools/scripts/internationalise.sh
tools/scripts/install-head.sh
tools/scripts/install-links.sh
tools/scripts/install-css.sh
tools/scripts/install-imports.sh
tools/scripts/install-highlight.sh
tools/scripts/install-a11y-css.sh

# 8. Install the feature mechanism into the generated layouts.
tools/scripts/install-features.sh
tools/scripts/install-top.sh

# 9. The contract is generated from the templates, and the static gate
#    compares the committed file against a fresh one. Without this the
#    first check fails on a file that never existed.
tools/scripts/docs.sh

# The one-shot pieces go, now that they have run. Keeping them leaves
# a project with a README template that overwrites its own README.
# The bootstrap workflow can never fire again either.
rm -f tools/templates/README.md.tmpl tools/templates/theme.toml.tmpl tools/templates/CHANGELOG.md.tmpl
rm -f .github/workflows/bootstrap.yml
rm -f BOOTSTRAP

# 10. Prove the pair before handing back.
./c conform || fail "the fresh scaffold does not conform. The suite is wrong, not the theme."

# 11. A repository made with the button has a one-commit history and a
#     remote of its own. A clone of the template has the template's
#     history and the template as its remote. Neither belongs to the
#     project. When the caller has named the project's owner and
#     repository, the clone is brought level here. When not, the
#     template's history and remote are left alone. The closing
#     message then says what to do by hand.
#
#     Deleting the ref under the checked-out branch leaves HEAD unborn
#     on that branch name. The index and the working tree stay intact.
#     The next commit is the root of the project's history. The old
#     commits stay in the object store until git prunes them. The
#     message names the one that restores them.
detached=no
if [ "$cloned" = yes ] && [ "$OWNER" != OWNER ]; then
  branch="$(git symbolic-ref --short -q HEAD || true)"
  head="$(git rev-parse -q --verify HEAD || true)"
  # The project's remote, in the form the clone used: ssh or https, on
  # the same host.
  home="$(printf '%s' "$remote" | sed "s|[^/:]*/$TEMPLATE\$|$OWNER/$REPO|").git"
  git remote remove origin
  if [ -n "$branch" ] && [ -n "$head" ]; then
    git update-ref -d "refs/heads/$branch"
    detached=yes
  fi
fi

commit="git add -A && git commit -m \"Generate theme scaffold from Hugo $version\""
printf '\n%s\n\n' "Generated $NAME ($SLUG) from Hugo $version."
if [ "$detached" = yes ]; then
  cat <<EOF
This was a clone of the template. Its history and its remote are gone.
The next commit starts the history of $OWNER/$REPO:

  $commit

To publish it:

  gh repo create $OWNER/$REPO --public --source=. --push

or, with $OWNER/$REPO created on GitHub:

  git remote add origin $home
  git push -u origin $branch

To undo instead, before committing:

  git reset --hard $head && git clean -fd
  git remote add origin $origin
EOF
elif [ "$cloned" = yes ]; then
  cat <<EOF
This is a clone of the template. It still has the template's history
and the template as its remote. A project of its own starts like this:

  git remote remove origin
  git update-ref -d refs/heads/$(git symbolic-ref --short -q HEAD || echo main)
  $commit

Then create the repository on GitHub, add it as origin, and push.
Running init with owner= and repo= does the first two steps.
EOF
else
  printf '  %s\n' "$commit"
fi
printf '\n'
