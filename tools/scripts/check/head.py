#!/usr/bin/env python3
"""Every page carries one title, one description, one canonical, one h1.

A page missing any of them is still published and still crawled. It is
also still wrong, so this is a gate rather than a warning.

The h1 count covers the whole document, the header included. A site
title in a header is still an h1 to a screen reader. A page carrying
two of them has no single heading.

An alias is a redirect holding a meta refresh and nothing else. Hugo
writes one for every moved or translated page. None of these rules fit
a page that no reader ever sees.
"""

import os
import sys

sys.path.insert(0, os.path.join("tools", "conformance", "scripts"))
import skeleton  # noqa: E402


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "tools/conformance/public/ours"
    findings = []
    for rel, full in skeleton.pages(root):
        page = skeleton.read(full)
        head = page.head()
        if head["redirect"]:
            continue
        if head["h1_total"] != 1:
            findings.append("%s:1: %d h1 headings. One per page." % (rel, head["h1_total"]))
        if not head["title"]:
            findings.append("%s:1: no title element." % rel)
        if not head["description"]:
            findings.append("%s:1: no meta description with content." % rel)
        if not head["canonical"]:
            findings.append("%s:1: no rel=canonical." % rel)
        if not head["og"].get("og:title"):
            findings.append("%s:1: no og:title." % rel)
        if not head["og"].get("og:description"):
            findings.append("%s:1: no og:description." % rel)
        if not head["lang"]:
            findings.append("%s:1: no lang on the html element." % rel)
        with open(full, encoding="utf-8", errors="replace") as handle:
            if "raw HTML omitted" in handle.read():
                findings.append("%s:1: 'raw HTML omitted' marker. Goldmark dropped markup." % rel)
    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
