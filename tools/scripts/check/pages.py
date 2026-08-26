#!/usr/bin/env python3
"""List the built pages a reader can actually read.

Hugo writes a stub for every alias and for each language root. It holds
a meta refresh, a title and nothing else, on purpose.

Asking one for a heading, a description or a landmark asks for what it
must never have. The validator, htmltest and pa11y each said so.
"""

import os
import re
import sys

REDIRECT = re.compile(r'http-equiv\s*=\s*["\']?refresh', re.IGNORECASE)


def is_redirect(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        return bool(REDIRECT.search(handle.read(4096)))


def readable(root):
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in ("css", "js", "fonts"))
        for name in sorted(files):
            if not name.endswith(".html"):
                continue
            full = os.path.join(folder, name)
            if not is_redirect(full):
                yield full


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "tools/conformance/public/ours"
    for path in readable(root):
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
