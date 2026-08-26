#!/usr/bin/env python3
"""Print the pa11y-ci config, with every built page in it.

The config shipped with an empty list, and pa11y-ci reports success when
it is given nothing to read. A gate that passes on no input is worse
than no gate, because it reads as evidence.
"""

import json
import os
import sys


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "conformance/public/ours"
    base = sys.argv[2] if len(sys.argv) > 2 else None

    config = {"defaults": {}, "urls": []}
    if base and os.path.exists(base):
        with open(base, encoding="utf-8") as handle:
            config = json.load(handle)

    urls = []
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in ("css", "js", "fonts"))
        for name in sorted(files):
            if name.endswith(".html"):
                urls.append(os.path.abspath(os.path.join(folder, name)))
    config["urls"] = urls
    json.dump(config, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
