#!/usr/bin/env python3
"""Reduce a built page to the shape a reader sees.

One JSON document per HTML file. The h1 and the heading outline. The
links and images inside the content. A count of the block elements, and
every classed element with the text it carries.

Two themes that render the same pages agree here, whatever their markup
and their stylesheet.

The classed elements are what makes a feature visible. A feature
declares what it adds, as a tag and a class. The declaration is then
checked against what actually appeared.

Chrome is excluded. A link in a nav or a footer belongs to the theme
rather than the page. Comparing it would report every menu.

Usage:
    skeleton.py DIR [--out DIR]
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
        # The classed elements open around the cursor, innermost last.
        # A link records the nearest one. A feature can then declare the
        # links it adds by naming the container it puts them in.
        self.classed = []
        # Inside a code block nothing is page shape. Syntax highlighting
        # puts a class on every token, and recording those would bury
        # the page in presentation.
        self.pre_depth = 0
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
        self.frames = []

    # A page with <main> defines its content that way. A page without one
    # counts everything outside the chrome elements.
    def in_content(self):
        if self.chrome_depth:
            return False
        return bool(self.main_depth) or not self.seen_main

    def container(self):
        """The nearest classed element open around the cursor."""
        return self.classed[-1][1] if self.classed else ""

    def handle_starttag(self, tag, attrs):
        attr = dict(attrs)
        # Read the container before this element joins the stack, or an
        # element would be recorded as its own container.
        parent = self.container()
        if tag not in VOID and attr.get("class"):
            names = attr["class"].split()
            label = "%s.%s" % (tag, names[0]) if names else tag
            self.classed.append((tag, label))

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
        if tag == "pre":
            self.pre_depth += 1
        if self.pre_depth and tag != "pre":
            return
        if tag == "img":
            self.images.append([attr.get("src", ""), attr.get("alt")])
            return
        if tag in VOID:
            # It never closes, so a frame opened here would swallow the
            # rest of the document.
            return

        # A heading is a heading first, whatever classes it carries.
        # A link inside one is recorded as well as the heading. That is
        # why the frames are a stack rather than a single slot.
        if tag == "h1":
            self.push(tag, "h1", None)
        elif tag in HEADINGS:
            self.push(tag, "heading", (attr.get("id", ""), parent))
        elif tag == "a" and "href" in attr:
            self.push(tag, "link", (attr["href"], parent))
        elif attr.get("class"):
            self.push(tag, "marked", attr["class"])

    def push(self, tag, kind, pending):
        self.frames.append({"tag": tag, "kind": kind, "pending": pending,
                            "buffer": []})

    def handle_endtag(self, tag):
        if tag == "pre":
            self.pre_depth = max(0, self.pre_depth - 1)
        for index in range(len(self.frames) - 1, -1, -1):
            if self.frames[index]["tag"] == tag:
                for frame in self.frames[index:]:
                    self.emit(frame)
                del self.frames[index:]
                break
        for index in range(len(self.classed) - 1, -1, -1):
            if self.classed[index][0] == tag:
                del self.classed[index:]
                break
        if tag == "main":
            self.main_depth = max(0, self.main_depth - 1)
        elif tag in CHROME:
            self.chrome_depth = max(0, self.chrome_depth - 1)

    def handle_data(self, data):
        # Every open frame collects the text. A heading holding a link
        # records its own words, and so does the link.
        for frame in self.frames:
            frame["buffer"].append(data)

    def emit(self, frame):
        text = " ".join("".join(frame["buffer"]).split())
        kind = frame["kind"]
        if kind == "link":
            href, parent = frame["pending"]
            self.links.append([href, text, parent])
        elif kind == "h1":
            self.h1.append(text)
        elif kind == "heading":
            identifier, parent = frame["pending"]
            self.headings.append([int(frame["tag"][1]), identifier, text, parent])
        elif kind == "marked":
            for name in (frame["pending"] or "").split():
                self.marked.append(["%s.%s" % (frame["tag"], name), text])

    def flush(self):
        """Close every frame still open at the end of the document."""
        for frame in self.frames:
            self.emit(frame)
        self.frames = []

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
    args = parser.parse_args()

    # Asserting belongs to head.sh, which owns the rules about what a
    # page must carry. Two copies of a rule drift apart.
    tree = {}
    for rel, full in pages(args.root):
        tree[rel] = read(full).document()

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

    return 0


if __name__ == "__main__":
    sys.exit(main())
