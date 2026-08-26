#!/usr/bin/env python3
"""Report a fixture page carrying a custom key at the top of its front matter.

Hugo owns the top level of front matter. A theme that reads a custom key
there works until Hugo takes the name, and then it breaks quietly. The
place for a theme's own key is params.
"""

import os
import re
import sys

RESERVED = {
    "aliases", "audio", "build", "cascade", "categories", "date", "description",
    "draft", "expiryDate", "headless", "images", "isCJKLanguage", "keywords",
    "kind", "lastmod", "layout", "linkTitle", "markup", "menu", "menus",
    "outputs", "params", "publishDate", "resources", "sitemap", "slug",
    "summary", "tags", "title", "translationKey", "type", "url", "videos",
    "weight", "authors", "series", "content", "objects",
}
DELIMITERS = {"---": "---", "+++": "+++"}
KEY = re.compile(r"^([A-Za-z_][\w-]*)\s*[:=]")


def front_matter(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        lines = handle.read().splitlines()
    if not lines or lines[0].strip() not in DELIMITERS:
        return []
    closing = DELIMITERS[lines[0].strip()]
    out = []
    for number, line in enumerate(lines[1:], start=2):
        if line.strip() == closing:
            break
        out.append((number, line))
    return out


def main():
    findings = []
    for root, dirs, files in os.walk("tools/conformance/content"):
        dirs[:] = [d for d in dirs if d != "scale"]
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            for number, line in front_matter(path):
                if line[:1] in (" ", "\t"):
                    continue
                match = KEY.match(line)
                if match and match.group(1) not in RESERVED:
                    findings.append(
                        "%s:%d: %s is not a Hugo key. Put it under params."
                        % (path, number, match.group(1)))
    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
