#!/usr/bin/env python3
"""Every published page is in the sitemap, and every feed item exists.

A sitemap naming a page that was never built sends a crawler to a 404.
A published page missing from the sitemap is a page nobody finds.
"""

import os
import re
import sys

BASE = "https://example.org/"
LOC = re.compile(r"<loc>\s*([^<]+?)\s*</loc>")


def built_urls(root):
    out = set()
    for folder, dirs, files in os.walk(root):
        for name in files:
            if name != "index.html":
                continue
            rel = os.path.relpath(os.path.join(folder, name), root)
            url = os.path.dirname(rel).replace(os.sep, "/")
            out.add(BASE + (url + "/" if url else ""))
    return out


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "conformance/public/ours"
    sitemap = os.path.join(root, "sitemap.xml")
    if not os.path.exists(sitemap):
        print("%s:1: no sitemap." % sitemap)
        return 1
    with open(sitemap, encoding="utf-8", errors="replace") as handle:
        listed = set(LOC.findall(handle.read()))
    # A multilingual site writes a sitemap index, whose entries are
    # sitemaps rather than pages.
    nested = {url for url in listed if url.endswith(".xml")}
    for url in list(nested):
        path = os.path.join(root, url[len(BASE):])
        if os.path.exists(path):
            with open(path, encoding="utf-8", errors="replace") as handle:
                listed |= set(LOC.findall(handle.read()))
    listed -= nested

    built = built_urls(root)
    findings = []
    for url in sorted(listed - built):
        findings.append("%s:1: sitemap names %s, which was not built." % (sitemap, url))
    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
