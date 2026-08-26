#!/usr/bin/env python3
"""Reduce a built page to the shape a reader sees.

One JSON document per HTML file: the h1, the heading outline, the links
and images inside the content, a count of the block elements, and every
classed element with the text it carries. Two themes that render the
same pages agree here, whatever their markup and their stylesheet.

The classed elements are what makes a feature visible. A feature
declares what it adds, as tag and class, and the declaration is checked
against what actually appeared.

Chrome is excluded. A link in a nav or a footer belongs to the theme, not
to the page, and comparing it would report every menu as a difference.

Usage:
    skeleton.py DIR [--out DIR] [--assert-single-h1] [--assert-description]
"""

import argparse
import json
import os
import sys
from html.parser import HTMLParser

CHROME = {"nav", "header", "footer", "aside"}
# An element that never closes cannot hold anything, so it never becomes
# the container of a link.
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link",
        "meta", "param", "source", "track", "wbr"}
COUNTED = ("table", "dl", "ul", "ol", "figure", "blockquote", "pre")
HEADINGS = ("h2", "h3", "h4", "h5", "h6")


class Skeleton(HTMLParser):
    """Walk one page and record what a reader would find on it."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.h1 = []
        self.marked = []
        # The classed elements open around the cursor, innermost last. A
        # link records the nearest one, so a feature can declare the
        # links it adds by naming the container it puts them in.
        self.classed = []
        self.headings = []
        self.links = []
        self.images = []
        self.counts = {name: 0 for name in COUNTED}
        self.title = None
        self.description = None
        self.canonical = None
        self.lang = None
        self.og = {}
        self.scripts = 0
        self.h1_total = 0
        self.redirect = False
        self.main_depth = 0
        self.chrome_depth = 0
        self.seen_main = False
        self.capture = None
        self.buffer = []
        self.pending = None

    # A page with <main> defines its content that way. A page without one
    # counts everything outside the chrome elements.
    def in_content(self):
        if self.chrome_depth:
            return False
        return bool(self.main_depth) or not self.seen_main

    def container(self):
        return self.classed[-1][1] if self.classed else ""

    def handle_starttag(self, tag, attrs):
        attr = dict(attrs)
        if tag not in VOID and attr.get("class"):
            first = attr["class"].split()[0] if attr["class"].split() else ""
            self.classed.append((tag, "%s.%s" % (tag, first) if first else tag))
        if tag == "main":
            self.seen_main = True
            self.main_depth += 1
        elif tag in CHROME:
            self.chrome_depth += 1
        elif tag == "html":
            self.lang = attr.get("lang")
        elif tag == "script" and attr.get("src"):
            self.scripts += 1
        elif tag == "meta":
            if (attr.get("http-equiv") or "").lower() == "refresh":
                self.redirect = True
            name = (attr.get("name") or "").lower()
            prop = (attr.get("property") or "").lower()
            if name == "description":
                self.description = attr.get("content", "")
            elif prop.startswith("og:"):
                self.og[prop] = attr.get("content", "")
        elif tag == "link" and (attr.get("rel") or "").lower() == "canonical":
            self.canonical = attr.get("href")

        if tag == "h1":
            self.h1_total += 1
        if not self.in_content():
            return
        if tag in self.counts:
            self.counts[tag] += 1
        elif tag == "img":
            self.images.append([attr.get("src", ""), attr.get("alt")])
        elif tag == "a" and "href" in attr:
            self.flush()
            self.capture = "a"
            self.pending = (attr["href"], self.container())
        elif tag == "h1":
            self.flush()
            self.capture = "h1"
        elif attr.get("class"):
            self.flush()
            self.capture = tag
            self.pending = attr["class"]
        elif tag in HEADINGS:
            self.flush()
            self.capture = tag
            self.pending = (attr.get("id", ""), self.container())

    def handle_endtag(self, tag):
        for index in range(len(self.classed) - 1, -1, -1):
            if self.classed[index][0] == tag:
                del self.classed[index:]
                break
        if tag == "main":
            self.main_depth = max(0, self.main_depth - 1)
        elif tag in CHROME:
            self.chrome_depth = max(0, self.chrome_depth - 1)
        if self.capture == tag:
            self.flush()

    def handle_data(self, data):
        if self.capture:
            self.buffer.append(data)

    def flush(self):
        if not self.capture:
            return
        text = " ".join("".join(self.buffer).split())
        if self.capture == "a":
            href, container = self.pending
            self.links.append([href, text, container])
        elif self.capture == "h1":
            self.h1.append(text)
        elif self.capture in HEADINGS:
            level = int(self.capture[1])
            identifier, container = self.pending
            self.headings.append([level, identifier, text, container])
        else:
            for name in (self.pending or "").split():
                self.marked.append(["%s.%s" % (self.capture, name), text])
        self.capture, self.buffer, self.pending = None, [], None

    def document(self):
        return {
            "h1": self.h1[0] if self.h1 else None,
            "h1_count": len(self.h1),
            "headings": self.headings,
            "links": self.links,
            "images": self.images,
            "counts": self.counts,
            "marked": self.marked,
        }

    def head(self):
        return {
            "title": self.title,
            "description": self.description,
            "canonical": self.canonical,
            "lang": self.lang,
            "og": self.og,
            "scripts": self.scripts,
            "h1_total": self.h1_total,
            "redirect": self.redirect,
        }


class WithTitle(Skeleton):
    """Skeleton, plus the contents of the title element."""

    def __init__(self):
        super().__init__()
        self.in_title = False
        self.title_buffer = []

    def handle_starttag(self, tag, attrs):
        if tag == "title":
            self.in_title = True
        super().handle_starttag(tag, attrs)

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False
            self.title = " ".join("".join(self.title_buffer).split())
        super().handle_endtag(tag)

    def handle_data(self, data):
        if self.in_title:
            self.title_buffer.append(data)
        super().handle_data(data)


def read(path):
    parser = WithTitle()
    with open(path, encoding="utf-8", errors="replace") as handle:
        parser.feed(handle.read())
    parser.flush()
    return parser


def pages(root):
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in ("css", "js", "fonts"))
        for name in sorted(files):
            if name.endswith(".html"):
                full = os.path.join(folder, name)
                yield os.path.relpath(full, root).replace(os.sep, "/"), full


def main():
    parser = argparse.ArgumentParser(description="Reduce built pages to their shape.")
    parser.add_argument("root", help="a built site, such as public/ours")
    parser.add_argument("--out", help="write one JSON file per page into this directory")
    parser.add_argument("--assert-single-h1", action="store_true")
    parser.add_argument("--assert-description", action="store_true")
    args = parser.parse_args()

    findings = []
    tree = {}
    for rel, full in pages(args.root):
        page = read(full)
        tree[rel] = page.document()
        head = page.head()
        if args.assert_single_h1 and page.document()["h1_count"] != 1:
            findings.append(f"{rel}:1: {page.document()['h1_count']} h1 headings. One per page.")
        if args.assert_description and not head["description"]:
            findings.append(f"{rel}:1: no meta description.")

    if args.out:
        os.makedirs(args.out, exist_ok=True)
        for rel, document in tree.items():
            target = os.path.join(args.out, rel.replace("/", "__") + ".json")
            with open(target, "w", encoding="utf-8") as handle:
                json.dump(document, handle, indent=2, sort_keys=True)
                handle.write("\n")
    else:
        json.dump(tree, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")

    for finding in findings:
        print(finding, file=sys.stderr)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
