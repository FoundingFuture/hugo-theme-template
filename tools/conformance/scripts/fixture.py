#!/usr/bin/env python3
"""Write the scale fixture.

A template running a site-wide query inside a per-page loop is fast on
twenty pages and slow on two thousand. The cost shows up here and
nowhere else. The fixture exists to make it show up.

The content is generated, not committed, and its directory is
gitignored. It sits outside content/, so only the scale build mounts
it. Two thousand pages inside content/ would slow every other
build and drown every other gate in tag pages.
"""

import argparse
import os
import shutil

WORDS = (
    "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu "
    "nu xi omicron pi rho sigma tau upsilon phi chi psi omega ridge harbour "
    "lantern gravel meadow cinder thicket furrow quarry sable".split())
TAGS = ["tag-%02d" % n for n in range(40)]
CATEGORIES = ["category-%d" % n for n in range(8)]
DEST = "tools/conformance/scale-content"


def words(count, seed):
    return " ".join(WORDS[(seed * 7 + n * 13) % len(WORDS)] for n in range(count))


def page(index):
    """One post, dated across ten years, with three headings and tags."""
    year = 2016 + (index % 10)
    month = (index % 12) + 1
    day = (index % 28) + 1
    tags = [TAGS[(index + n * 3) % len(TAGS)] for n in range(2 + index % 3)]
    category = CATEGORIES[index % len(CATEGORIES)]
    body = []
    for section in range(3):
        body.append("## %s" % words(3, index + section).capitalize())
        body.append("")
        # The length varies, so a partial reporting a reading time
        # returns different markup and its cache potential means
        # something. Every post the same length made it read as
        # perfectly cacheable, which was true of the fixture only.
        body.append(words(60 + (index * 7 + section * 11) % 180, index + section * 5))
        body.append("")
    return (
        "+++\n"
        "title = 'Scale post %d'\n"
        "date = %04d-%02d-%02dT08:00:00Z\n"
        "description = 'Generated post %d of the scale fixture, carrying tags, a category and three headings.'\n"
        "tags = [%s]\n"
        "categories = ['%s']\n"
        "+++\n\n%s"
        % (index, year, month, day, index,
           ", ".join("'%s'" % tag for tag in tags), category, "\n".join(body)))


def main():
    parser = argparse.ArgumentParser(description="Generate the scale fixture.")
    parser.add_argument("--size", type=int, default=2000)
    parser.add_argument("--dest", default=DEST)
    args = parser.parse_args()

    if os.path.isdir(args.dest):
        shutil.rmtree(args.dest)
    os.makedirs(args.dest)
    with open(os.path.join(args.dest, "_index.md"), "w", encoding="utf-8") as handle:
        handle.write(
            "+++\ntitle = 'Scale'\ndate = 2016-01-01T08:00:00Z\n"
            "description = 'The generated section the scale build measures, holding every generated post.'\n+++\n")
    for index in range(args.size):
        target = os.path.join(args.dest, "scale-%05d.md" % index)
        with open(target, "w", encoding="utf-8") as handle:
            handle.write(page(index))
    print("wrote %d pages into %s" % (args.size, args.dest))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
