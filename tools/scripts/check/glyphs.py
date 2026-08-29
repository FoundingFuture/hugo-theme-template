#!/usr/bin/env python3
"""Every mark the theme draws exists in a face that can draw it.

A woff2 shipped with a theme is a subset. It carries the letters the
theme needs and nothing else, which is what keeps it small. Ask it for
a character it does not have and the browser reaches past it to
whatever the reader's system offers: a different shape, from a
different typeface, at a different weight, on every platform. Nothing
reports it. The page simply looks wrong somewhere else.

Two rules, and both are read from the stylesheet rather than kept in a
list here.

A mark written in a rule that names a font-family has to exist in one
of the faces that stack names. That is the promise the rule makes.

A mark written anywhere else has to exist in every face a mark can
land in without being named: the display, the text and the mono the
palette declares. A face used only in one place, like the menu's cut,
is named where it is used and is not held to this.
"""

import glob
import os
import re
import sys

try:
    from fontTools.ttLib import TTFont
except ImportError:
    print("SKIP glyphs: fontTools is not installed. ./c setup fetches it")
    sys.exit(3)

CSS = "assets/css"
FONTS = "assets/fonts"
SCANNED = ["layouts/**/*.html", "i18n/*.toml"]


def stylesheet():
    text = ""
    for path in sorted(glob.glob(os.path.join(CSS, "**", "*.css"), recursive=True)):
        text += open(path, encoding="utf-8").read() + "\n"
    return re.sub(r"/\*.*?\*/", " ", text, flags=re.S)


def faces(css):
    """Each font-family the stylesheet declares, and the file behind it."""
    out = {}
    for block in re.findall(r"@font-face\s*\{(.*?)\}", css, re.S):
        family = re.search(r"font-family\s*:\s*['\"]?([^;'\"]+)", block)
        source = re.search(r"url\(['\"]?([^)'\"]+)", block)
        if family and source:
            out[family.group(1).strip()] = os.path.basename(source.group(1))
    return out


def coverage(name):
    font = TTFont(os.path.join(FONTS, name))
    seen = set()
    for table in font["cmap"].tables:
        seen |= set(table.cmap.keys())
    return seen


def properties(css):
    """The custom properties naming a family, so var() can be resolved."""
    out = {}
    for block in re.findall(r":root\s*\{(.*?)\}", css, re.S):
        for name, value in re.findall(r"(--[\w-]+)\s*:\s*([^;]+)", block):
            out[name] = value.strip()
    return out


def stack(value, props, depth=0):
    """The families a font-family value names, var() resolved."""
    if depth > 4:
        return []
    while "var(" in value:
        match = re.search(r"var\(\s*(--[\w-]+)[^)]*\)", value)
        if not match:
            break
        value = value.replace(match.group(0), props.get(match.group(1), ""))
    return [part.strip().strip("'\"") for part in value.split(",") if part.strip()]


def marks(text):
    """Characters above ASCII, written plainly or escaped."""
    found = set()
    for ch in text:
        if ord(ch) > 126:
            found.add(ch)
    for code in re.findall(r"&#(\d+);", text):
        found.add(chr(int(code)))
    for code in re.findall(r"\\([0-9A-Fa-f]{4})", text):
        found.add(chr(int(code, 16)))
    return found


def main():
    if not os.path.isdir(FONTS):
        print("glyphs: the theme ships no faces of its own")
        return 0

    css = stylesheet()
    declared = faces(css)
    if not declared:
        print("glyphs: the stylesheet declares no face")
        return 0
    have = {name: coverage(f) for name, f in declared.items()
            if os.path.exists(os.path.join(FONTS, f))}
    props = properties(css)

    core = []
    for key in ("--display", "--text", "--mono"):
        for family in stack(props.get(key, ""), props):
            if family in have and family not in core:
                core.append(family)

    findings = []

    # A rule that names a face promises the mark is in that stack.
    for block in re.findall(r"\{([^{}]*)\}", css):
        if "content" not in block:
            continue
        value = re.search(r"content\s*:\s*([^;]+)", block)
        if not value:
            continue
        wanted = marks(value.group(1))
        if not wanted:
            continue
        named = re.search(r"font-family\s*:\s*([^;]+)", block)
        if named:
            families = [f for f in stack(named.group(1), props) if f in have]
            for ch in sorted(wanted):
                if families and not any(ord(ch) in have[f] for f in families):
                    findings.append(
                        "%s:1: %r is drawn by no face the rule names (%s)."
                        % (CSS, ch, ", ".join(families)))
        else:
            for ch in sorted(wanted):
                missing = [f for f in core if ord(ch) not in have[f]]
                if missing:
                    findings.append(
                        "%s:1: %r is written with no face named, and %s has none."
                        % (CSS, ch, ", ".join(missing)))

    # Anything the templates and the words carry lands in a core face.
    for pattern in SCANNED:
        for path in sorted(glob.glob(pattern, recursive=True)):
            body = open(path, encoding="utf-8").read()
            body = re.sub(r"\{\{-?\s*/\*.*?\*/\s*-?\}\}", " ", body, flags=re.S)
            body = re.sub(r"(?m)^\s*#.*$", " ", body)
            for ch in sorted(marks(body)):
                missing = [f for f in core if ord(ch) not in have[f]]
                if missing:
                    findings.append(
                        "%s:1: %r is not in %s." % (path, ch, ", ".join(missing)))

    for line in sorted(set(findings)):
        print(line)
    if findings:
        return 1
    print("glyphs: every mark is in a face that draws it, across %d faces"
          % len(have))
    return 0


if __name__ == "__main__":
    sys.exit(main())
