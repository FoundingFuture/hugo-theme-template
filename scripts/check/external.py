#!/usr/bin/env python3
"""Every reference resolves under the site, or it is a third-party request.

A theme that pulls a font or a script from another host makes every
page load depend on that host. It also tells that host who is reading.
A subresource from elsewhere carries an integrity attribute, or it is
not trusted.
"""

import os
import re
import sys
from urllib.parse import urlparse

BASE = "https://example.org/"
REFERENCE = re.compile(
    r'(?:src|href)\s*=\s*["\']([^"\']+)["\']'
    r'|srcset\s*=\s*["\']([^"\']+)["\']'
    r'|url\(\s*["\']?([^"\')]+)'
    r'|@import\s+["\']([^"\']+)')
SUBRESOURCE = re.compile(
    r'<(script)\b[^>]*\bsrc\s*=|<(link)\b[^>]*\brel\s*=\s*["\']stylesheet["\']',
    re.IGNORECASE)
TAG = re.compile(r"<(?:script|link)\b[^>]*>", re.IGNORECASE)


def local(target):
    target = target.strip()
    if not target or target.startswith(("#", "mailto:", "tel:", "data:")):
        return True
    parsed = urlparse(target)
    if not parsed.scheme and not parsed.netloc:
        return True
    return target.startswith(BASE)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "conformance/public/ours"
    if not os.path.isdir(root):
        print("SKIP external: no build at %s" % root)
        return 3
    findings = []
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(dirs)
        for name in sorted(files):
            if not name.endswith((".html", ".css", ".xml")):
                continue
            full = os.path.join(folder, name)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            with open(full, encoding="utf-8", errors="replace") as handle:
                text = handle.read()
            for number, line in enumerate(text.splitlines(), start=1):
                for groups in REFERENCE.findall(line):
                    for target in groups:
                        if not target:
                            continue
                        for piece in target.split(","):
                            piece = piece.strip().split(" ")[0]
                            if piece and not local(piece):
                                findings.append(
                                    "%s:%d: %s is a third-party request." % (rel, number, piece))
            if name.endswith(".html"):
                for tag in TAG.findall(text):
                    if not SUBRESOURCE.search(tag):
                        continue
                    match = re.search(r'(?:src|href)\s*=\s*["\']([^"\']+)', tag)
                    if match and not local(match.group(1)) and "integrity=" not in tag:
                        findings.append(
                            "%s:1: %s has no integrity attribute." % (rel, match.group(1)))
    for finding in sorted(set(findings)):
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
