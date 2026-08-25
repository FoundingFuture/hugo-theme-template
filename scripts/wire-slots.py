#!/usr/bin/env python3
"""Place the slot calls in the generated templates, once, at bootstrap.

A slot renders every enabled feature registered for it. With no feature
installed a slot renders nothing. The generated theme therefore still
matches the reference scaffold, page for page.

The insertion points are the ones the slot table names. Each is found
by the markup the Hugo scaffold writes. A template already wired is
left alone.
"""

import os
import re
import sys

CALL = '{{ partial "slot.html" (dict "slot" "%s" "page" .) }}'


def wire(path, edits):
    if not os.path.exists(path):
        return False
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    if 'partial "slot.html"' in text:
        return False
    original = text
    for pattern, replacement in edits:
        text = re.sub(pattern, replacement, text, count=1)
    if text == original:
        return False
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    return True


def main():
    partials = sys.argv[1] if len(sys.argv) > 1 else "layouts/_partials"
    changed = []

    if wire("layouts/baseof.html", [
        (r"(?m)^(\s*)</head>", lambda m: "%s  %s\n%s</head>" % (
            m.group(1), CALL % "head", m.group(1))),
        (r"(?m)^(\s*)</body>", lambda m: "%s  %s\n%s</body>" % (
            m.group(1), CALL % "body.end", m.group(1))),
    ]):
        changed.append("layouts/baseof.html")

    if wire("layouts/page.html", [
        (r"(?m)^(\s*)<h1>", lambda m: "%s%s\n%s<h1>" % (
            m.group(1), CALL % "page.before-title", m.group(1))),
        (r"(?m)^(\s*)\{\{ \$dateMachine", lambda m: "%s%s\n%s{{ $dateMachine" % (
            m.group(1), CALL % "page.after-title", m.group(1))),
        (r"(?m)^(\s*)\{\{ \.Content \}\}", lambda m: "%s%s\n%s{{ .Content }}\n%s%s" % (
            m.group(1), CALL % "page.meta", m.group(1), m.group(1),
            CALL % "page.after-body")),
    ]):
        changed.append("layouts/page.html")

    for name in ("section.html", "term.html"):
        if wire("layouts/%s" % name, [
            (r"(?m)^(\s*)\{\{ end \}\}\s*$", lambda m: "%s%s\n%s{{ end }}" % (
                m.group(1), CALL % "list.after", m.group(1))),
        ]):
            changed.append("layouts/%s" % name)

    for name in changed:
        print("wired %s" % name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
