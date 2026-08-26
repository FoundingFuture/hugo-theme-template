#!/usr/bin/env python3
"""Place the slot calls in the generated templates, once, at bootstrap.

A slot renders every enabled feature registered for it. The insertion
points are the ones the slot table names, found by the markup the Hugo
scaffold writes. A template already wired is left alone.

A slot with no enabled feature renders nothing. A theme with every
feature switched off still matches the reference scaffold.
"""

import os
import re
import sys

CALL = '{{ partial "slot.html" (dict "slot" "%s" "page" .) }}'


def indent_of(line):
    return line[:len(line) - len(line.lstrip())]


def wire(path, edits):
    """Apply the edits to one template, unless it is already wired."""
    if not os.path.exists(path):
        return False
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    if 'partial "slot.html"' in text:
        return False
    original = text
    for pattern, build in edits:
        text = re.sub(pattern, build, text, count=1)
    if text == original:
        return False
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    return True


def before(slot):
    """Put the call on its own line above whatever was matched."""
    def build(match):
        pad = indent_of(match.group(0))
        return "%s%s\n%s" % (pad, CALL % slot, match.group(0))
    return build


def after(slot):
    def build(match):
        pad = indent_of(match.group(0))
        return "%s\n%s%s" % (match.group(0), pad, CALL % slot)
    return build


def main():
    changed = []

    if wire("layouts/baseof.html", [
        (r"(?m)^[ \t]*</head>", before("head")),
        (r"(?m)^[ \t]*</body>", before("body.end")),
    ]):
        changed.append("layouts/baseof.html")

    if wire("layouts/page.html", [
        (r"(?m)^[ \t]*<h1>", before("page.before-title")),
        (r"(?m)^[ \t]*\{\{ \$dateMachine", before("page.after-title")),
        # Both sit above the body. meta holds the dateline and its
        # neighbours. before-body holds whatever introduces the reading,
        # such as a table of contents.
        (r"(?m)^[ \t]*\{\{ \.Content \}\}", before("page.meta")),
        (r"(?m)^[ \t]*\{\{ \.Content \}\}", before("page.before-body")),
        (r"(?m)^[ \t]*\{\{ \.Content \}\}", after("page.after-body")),
        (r"(?m)^[ \t]*\{\{ partial \"terms\.html\".*$", after("page.footer")),
    ]):
        changed.append("layouts/page.html")

    for name in ("section.html", "term.html"):
        path = "layouts/%s" % name
        if wire(path, [
            (r"(?m)^[ \t]*</section>", before("list.item")),
            # Between the end of the range and the end of the block.
            # It then renders once after the rows, not once a row.
            (r"(?ms)^([ \t]*)\{\{ end \}\}\n(\{\{ end \}\})",
             lambda m: "%s{{ end }}\n%s%s\n%s" % (
                 m.group(1), m.group(1), CALL % "list.after", m.group(2))),
        ]):
            changed.append(path)

    if wire("layouts/home.html", [
        (r"(?ms)^([ \t]*)\{\{ end \}\}\n(\{\{ end \}\})",
         lambda m: "%s{{ end }}\n%s%s\n%s" % (
             m.group(1), m.group(1), CALL % "list.after", m.group(2))),
    ]):
        changed.append("layouts/home.html")

    for name in changed:
        print("wired %s" % name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
