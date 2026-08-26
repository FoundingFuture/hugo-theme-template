#!/usr/bin/env python3
"""The reference and the theme agree on the h1 of every page.

Bootstrap takes one h1 off the scaffold. The scaffold puts the site
title in an h1 in the header. The page title goes in a second h1 below
it. A page carrying two of them has no single heading.

The one taken away sits in the header, outside the content, so no
page's own h1 moves. That claim held when it was made, and this is what
keeps it holding. The skeleton comparison could be loosened later, and
then the h1 would go quiet rather than fail.
"""

import json
import subprocess
import sys


def skeleton(root):
    out = subprocess.run([sys.executable, "scripts/skeleton.py", root],
                         capture_output=True, text=True)
    if not out.stdout.strip():
        return {}
    return json.loads(out.stdout)


def main():
    reference = skeleton("public/hugo")
    ours = skeleton("public/ours-off")
    if not reference or not ours:
        print("SKIP h1: build public/hugo and public/ours-off first")
        return 3

    findings = []
    for path in sorted(set(reference) | set(ours)):
        left = reference.get(path)
        right = ours.get(path)
        if left is None or right is None:
            continue
        if left["h1"] != right["h1"]:
            findings.append("%s:1: the h1 reads %r in the reference and %r here."
                            % (path, left["h1"], right["h1"]))
        if left["h1_count"] != right["h1_count"]:
            findings.append("%s:1: %d h1 in the content in the reference, %d here."
                            % (path, left["h1_count"], right["h1_count"]))

    for finding in findings:
        print(finding)
    if not findings:
        print("h1: the reference and the theme agree on every page, %d checked"
              % len(reference))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
