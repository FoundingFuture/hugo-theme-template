#!/usr/bin/env python3
"""Hold a fixture page to what it says its output must contain.

A page may carry params.expect, a list of strings that must appear in
the page it builds to. It may also carry params.reject, listing what
must stay out.

The skeleton compares the shape of a page, and the manifests compare
what a feature adds. Neither reads the words.

A reading time rendered "1 minutes read" because a float reached a
plural rule. Every gate passed, because every gate was reading shape.
"""

import os
import re
import sys

CONTENT = "tools/conformance/content"
FRONT = re.compile(r"^\+\+\+\n(.*?)\n\+\+\+", re.S)
LIST = re.compile(r"^\s*(expect|reject)\s*=\s*\[(.*?)\]", re.S | re.M)
ITEM = re.compile(r"'([^']*)'|\"([^\"]*)\"")
TAG = re.compile(r"<[^>]+>")


def wanted(path):
    """Read params.expect and params.reject from a page's front matter."""
    with open(path, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    match = FRONT.match(text)
    if not match:
        return [], []
    expect, reject = [], []
    for name, body in LIST.findall(match.group(1)):
        values = [a or b for a, b in ITEM.findall(body)]
        if name == "expect":
            expect.extend(values)
        else:
            reject.extend(values)
    return expect, reject


def built(root, relative):
    """Where a content file lands in the built site."""
    stem = relative[: -len(".md")]
    if stem.endswith("/index") or stem.endswith("/_index"):
        stem = stem.rsplit("/", 1)[0]
    if stem in ("index", "_index"):
        return os.path.join(root, "index.html")
    return os.path.join(root, stem, "index.html")


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "tools/conformance/public/ours"
    findings = []
    checked = 0
    for folder, dirs, files in os.walk(CONTENT):
        dirs[:] = sorted(d for d in dirs if d != "scale")
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            source = os.path.join(folder, name)
            expect, reject = wanted(source)
            if not expect and not reject:
                continue
            relative = os.path.relpath(source, CONTENT).replace(os.sep, "/")
            page = built(root, relative)
            if not os.path.exists(page):
                findings.append("%s:1: says what its output holds, and builds to nothing." % source)
                continue
            checked += 1
            with open(page, encoding="utf-8", errors="replace") as handle:
                text = " ".join(TAG.sub(" ", handle.read()).split())
            for phrase in expect:
                if phrase not in text:
                    findings.append("%s:1: the page does not say %r." % (source, phrase))
            for phrase in reject:
                if phrase in text:
                    findings.append("%s:1: the page says %r, and must not." % (source, phrase))

    for finding in findings:
        print(finding)
    if not findings:
        word = "page holds" if checked == 1 else "pages hold"
        print("expect: %d %s to what it states" % (checked, word))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
