#!/usr/bin/env python3
"""Check the words a theme renders.

Three faults. A call with no key renders nothing, so a heading vanishes
without a message. A key with no call is dead weight for every
downloader. A bare text node in a template is English that no translation
can reach.
"""

import os
import re
import sys

# One entry a line. Each is matched against the whole visible string
# on a line, once the template actions and the tags are gone. The file
# carries no comment, because it is read as data.
ALLOW_FILE = "scripts/check/i18n-allow.txt"
CALL = re.compile(r'\b(?:i18n|T)\s+"([^"]+)"')
TABLE = re.compile(r"^\s*\[([^\]]+)\]")
BARE = re.compile(r"^\s*([A-Za-z_][\w-]*)\s*=")
# Text between template actions and outside a tag. Comments, doctypes and
# the inside of script or style are not prose.
ACTION = re.compile(r"\{\{.*?\}\}", re.DOTALL)
COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
BLOCK = re.compile(r"<(script|style)\b.*?</\1>", re.DOTALL | re.IGNORECASE)
TAG = re.compile(r"<[^>]*>", re.DOTALL)
LETTERS = re.compile(r"[A-Za-z]{2,}")


def layouts_dir():
    for candidate in ("layouts",):
        if os.path.isdir(candidate):
            return candidate
    return None


def templates(root):
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(dirs)
        for name in sorted(files):
            if name.endswith(".html"):
                yield os.path.join(folder, name)


def defined_keys(path):
    """Return the translation keys, not the plural forms inside them.

    A key is a table header, or a bare assignment before the first table.
    one and other live inside a key and are not keys themselves.
    """
    keys = set()
    if not os.path.exists(path):
        return keys
    in_table = False
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            table = TABLE.match(line)
            if table:
                keys.add(table.group(1))
                in_table = True
                continue
            if not in_table:
                bare = BARE.match(line)
                if bare:
                    keys.add(bare.group(1))
    return keys


def blank(pattern, text):
    """Remove every match, keeping the newlines so line numbers hold.

    A template action, a comment and a script block all span lines.
    Stripping them line by line would leave their tails looking like prose.
    """
    return pattern.sub(lambda m: "\n" * m.group(0).count("\n"), text)


def allow_list():
    if not os.path.exists(ALLOW_FILE):
        return set()
    out = set()
    with open(ALLOW_FILE, encoding="utf-8") as handle:
        for line in handle:
            line = line.split("#", 1)[0].strip()
            if line:
                out.add(line)
    return out


def main():
    root = layouts_dir()
    if root is None:
        print("layouts:1: no layouts directory.")
        return 1

    findings = []
    allow = allow_list()
    defined = defined_keys("i18n/en.toml")
    used = set()

    for path in templates(root):
        with open(path, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        for number, line in enumerate(text.splitlines(), start=1):
            for key in CALL.findall(line):
                used.add(key)
                if key not in defined:
                    findings.append(
                        "%s:%d: i18n key %s is not in i18n/en.toml. It renders as nothing."
                        % (path, number, key))
        stripped = blank(BLOCK, text)
        stripped = blank(COMMENT, stripped)
        stripped = blank(ACTION, stripped)
        for number, line in enumerate(stripped.splitlines(), start=1):
            prose = TAG.sub(" ", line).strip()
            if not prose or prose in allow:
                continue
            if LETTERS.search(prose):
                findings.append(
                    "%s:%d: visible string outside i18n: %s"
                    % (path, number, prose[:50]))

    for key in sorted(defined - used):
        findings.append("i18n/en.toml:1: key %s is defined and never used." % key)

    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
