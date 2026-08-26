#!/usr/bin/env bash
# Two rules the scaffold's stylesheet leaves out.
#
# A link in a paragraph is told apart from its text by colour alone.
# A reader who cannot see that colour cannot tell them apart.
#
# A link in a list sits flush against its neighbours, so a target ends
# up smaller than a finger.
#
# Lighthouse reports both. Neither shows in markup, so nothing else
# here was going to find them.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

sheet=assets/css/a11y.css
[ -f "$sheet" ] && exit 0
mkdir -p assets/css

cat > "$sheet" <<'CSS'
/* A link inside prose carries an underline. Colour is then not the
   only thing telling it from the words around it. */
main a {
  text-decoration: underline;
}

/* A link that is its own row needs no underline, since its position
   already tells it apart. It does need room to be tapped, and WCAG 2.2
   asks for 24 by 24 CSS pixels. */
main nav a,
main li > a:only-child {
  text-decoration: none;
}

main nav a,
main li > a {
  display: inline-block;
  min-block-size: 24px;
  padding-block: 2px;
}

main nav li + li {
  margin-block-start: 4px;
}
CSS
