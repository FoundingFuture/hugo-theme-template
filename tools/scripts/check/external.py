#!/usr/bin/env python3
"""Every subresource resolves under the site, or it is a third-party request.

A theme that pulls a font or a script from another host makes every page
load depend on that host. It also tells that host who is reading. A
subresource from elsewhere carries an integrity attribute, or it is not
trusted.

A link a reader may follow is not a subresource. An anchor pointing at
another site costs nothing until somebody clicks it. A fixture page
listing the link forms Hugo resolves has to carry one.

Such an anchor still says where it goes. It carries rel with external
and noopener. The difference between a link and a fetched subresource
then stays visible in the output. It does not live in this rule alone.
"""

import os
import re
import sys
from html.parser import HTMLParser
from urllib.parse import urlparse

BASE = "https://example.org/"
# Attributes the browser fetches without being asked.
FETCHED = {
    "img": ("src", "srcset"), "script": ("src",), "iframe": ("src",),
    "audio": ("src",), "video": ("src", "poster"), "source": ("src", "srcset"),
    "embed": ("src",), "track": ("src",), "object": ("data",), "input": ("src",),
    "link": ("href",),
}
# A link element that only describes the document fetches nothing.
LINK_NOT_FETCHED = {"canonical", "alternate", "author", "license", "prev", "next"}
SUBRESOURCE_REL = {"stylesheet", "preload", "modulepreload", "prefetch", "icon",
                   "apple-touch-icon", "manifest", "preconnect", "dns-prefetch"}
CSS_REFERENCE = re.compile(r"url\(\s*['\"]?([^'\")]+)|@import\s+['\"]([^'\"]+)")


def local(target):
    target = (target or "").strip()
    if not target or target.startswith(("#", "mailto:", "tel:", "data:", "javascript:")):
        return True
    parsed = urlparse(target)
    if not parsed.scheme and not parsed.netloc:
        return True
    return target.startswith(BASE)


class Subresources(HTMLParser):
    """Collect what the page fetches, and check what it points at."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.findings = []
        self.anchors = []

    def handle_starttag(self, tag, attrs):
        attr = dict(attrs)
        if tag == "a":
            target = attr.get("href")
            if target and not local(target):
                rel = set((attr.get("rel") or "").lower().split())
                missing = {"external", "noopener"} - rel
                if missing:
                    self.anchors.append(
                        (self.getpos()[0], target, sorted(missing)))
            return
        wanted = FETCHED.get(tag)
        if not wanted:
            return
        if tag == "link":
            rel = (attr.get("rel") or "").lower().split()
            if not rel or set(rel) & LINK_NOT_FETCHED:
                return
            if not set(rel) & SUBRESOURCE_REL:
                return
        for name in wanted:
            value = attr.get(name)
            if not value:
                continue
            for piece in value.split(","):
                target = piece.strip().split(" ")[0]
                if target and not local(target):
                    self.findings.append((self.getpos()[0], target, attr))


def check_html(path, rel, findings):
    parser = Subresources()
    with open(path, encoding="utf-8", errors="replace") as handle:
        parser.feed(handle.read())
    for line, target, attr in parser.findings:
        findings.append("%s:%d: %s is a third-party request." % (rel, line, target))
        if "integrity" not in attr:
            findings.append("%s:%d: %s has no integrity attribute." % (rel, line, target))
    for line, target, missing in parser.anchors:
        findings.append("%s:%d: the link to %s has no %s in its rel."
                        % (rel, line, target, " or ".join(missing)))


def check_css(path, rel, findings):
    with open(path, encoding="utf-8", errors="replace") as handle:
        for number, line in enumerate(handle, start=1):
            for groups in CSS_REFERENCE.findall(line):
                for target in groups:
                    if target and not local(target):
                        findings.append(
                            "%s:%d: %s is a third-party request." % (rel, number, target))


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "tools/conformance/public/ours"
    if not os.path.isdir(root):
        print("SKIP external: no build at %s" % root)
        return 3
    findings = []
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(dirs)
        for name in sorted(files):
            full = os.path.join(folder, name)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            if name.endswith(".html"):
                check_html(full, rel, findings)
            elif name.endswith(".css"):
                check_css(full, rel, findings)
    for finding in sorted(set(findings)):
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
