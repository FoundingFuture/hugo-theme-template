#!/usr/bin/env python3
"""The sitemap and the feeds agree with what was published.

Three faults. A sitemap naming a page that was never built sends a
crawler to a 404. A published page missing from the sitemap is a page
nobody finds. A feed item pointing at nothing is the same fault as the
first, one layer down.

Only the first was checked before. A theme could drop every page from
its sitemap and still pass.

Before any of that, every file read here has to parse. That test was
xmllint's. The standard library does it now, so a machine without
libxml2 checks the same things.
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

BASE = "https://example.org/"
LOC = re.compile(r"<loc>\s*([^<]+?)\s*</loc>")
ITEM_LINK = re.compile(r"<item>.*?<link>\s*([^<]+?)\s*</link>", re.S)

# A page Hugo publishes but a sitemap need not name.
NOT_LISTED = ("404.html",)


def well_formed(path, findings):
    # The file is this build's own output, never foreign input.
    # Guarding the parse against entity expansion would be a
    # dependency spent on nothing.
    try:
        ET.parse(path)
        return True
    except ET.ParseError as fault:
        findings.append("%s:1: not well formed. %s" % (path, fault))
        return False


def built_urls(root):
    out = set()
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in ("css", "js", "fonts"))
        for name in files:
            if name != "index.html":
                continue
            rel = os.path.relpath(os.path.join(folder, name), root)
            url = os.path.dirname(rel).replace(os.sep, "/")
            out.add(BASE + (url + "/" if url else ""))
    return out


def is_redirect(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        return 'http-equiv="refresh"' in handle.read()[:2000].lower().replace("'", '"')


def sitemap_urls(root, path, findings):
    with open(path, encoding="utf-8", errors="replace") as handle:
        listed = set(LOC.findall(handle.read()))
    nested = {url for url in listed if url.endswith(".xml")}
    for url in nested:
        target = os.path.join(root, url[len(BASE):])
        if os.path.exists(target):
            if not well_formed(target, findings):
                continue
            with open(target, encoding="utf-8", errors="replace") as handle:
                listed |= set(LOC.findall(handle.read()))
        else:
            findings.append("%s:1: names %s, which was not built." % (path, url))
    return listed - nested


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "tools/conformance/public/ours"
    findings = []
    sitemap = os.path.join(root, "sitemap.xml")
    if not os.path.exists(sitemap):
        print("%s:1: no sitemap." % sitemap)
        return 1

    # A sitemap that does not parse gets one finding and no agreement
    # check. Findings against a broken file would all be echoes of it.
    if not well_formed(sitemap, findings):
        for finding in findings:
            print(finding)
        return 1

    listed = sitemap_urls(root, sitemap, findings)
    built = built_urls(root)

    for url in sorted(listed - built):
        findings.append("%s:1: names %s, which was not built." % (sitemap, url))

    # The other direction, which nothing checked. A redirect is not a
    # page a crawler should be sent to, so it is not expected here.
    for url in sorted(built - listed):
        rel = url[len(BASE):]
        page = os.path.join(root, rel, "index.html") if rel else os.path.join(root, "index.html")
        if os.path.exists(page) and is_redirect(page):
            continue
        if rel.rstrip("/") in NOT_LISTED:
            continue
        findings.append("%s:1: %s was built and is in no sitemap." % (sitemap, url))

    for folder, dirs, files in os.walk(root):
        for name in sorted(files):
            if name != "index.xml":
                continue
            feed = os.path.join(folder, name)
            if not well_formed(feed, findings):
                continue
            with open(feed, encoding="utf-8", errors="replace") as handle:
                for link in ITEM_LINK.findall(handle.read()):
                    if link not in built:
                        findings.append(
                            "%s:1: an item points at %s, which was not built."
                            % (os.path.relpath(feed, root), link))

    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
