#!/usr/bin/env python3
"""Print the pa11y-ci config, with every readable page in it.

The config shipped with an empty list, and pa11y-ci reports success when
it is given nothing to read. A gate that passes on no input is worse
than no gate, because it reads as evidence.

A redirect stub is left out. It holds a meta refresh and nothing else,
so it has no landmark, no heading and no language to judge.
"""

import json
import os
import sys


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "tools/conformance/public/ours"
    base = sys.argv[2] if len(sys.argv) > 2 else None

    config = {"defaults": {}, "urls": []}
    if base and os.path.exists(base):
        with open(base, encoding="utf-8") as handle:
            config = json.load(handle)

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import pages as readable_pages

    urls = [os.path.abspath(p) for p in readable_pages.readable(root)]
    config["urls"] = urls
    json.dump(config, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
