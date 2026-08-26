#!/usr/bin/env python3
"""Every check declares what it reads, and every directory is read.

A gate that never walks a directory reports the same silence as a gate
that walks it and finds nothing. The difference matters, and only a
declaration makes it visible.

Each check carries a "reads:" comment naming its inputs. This gathers
them and compares the union against what the repository holds. A
directory added tomorrow then fails today's run, rather than going
unread until somebody notices.
"""

import os
import re
import subprocess
import sys

CHECKS = "tools/scripts/check"
# The runner dispatches and reads nothing of its own.
NOT_A_CHECK = {"run.sh"}
READS = re.compile(r"^#\s*reads:\s*(.+)$", re.MULTILINE)

# Generated, gitignored, or read by Hugo rather than by a check.
EXEMPT = {
    ".git", ".github", ".tools", "public", "resources", "docs",
    "tools/conformance", "tools/templates", "static", "archetypes", "images",
    "content",
}
# A file type no check is expected to read.
CHECKABLE = {".sh", ".py", ".js", ".css", ".html", ".toml", ".md", ".yml"}


def tracked():
    try:
        out = subprocess.run(["git", "ls-files"], capture_output=True,
                             text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return []
    return out.splitlines()


def declared():
    paths = set()
    missing = []
    for name in sorted(os.listdir(CHECKS)):
        if not name.endswith(".sh") or name in NOT_A_CHECK:
            continue
        full = os.path.join(CHECKS, name)
        with open(full, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        match = READS.search(text)
        if not match:
            missing.append("%s:1: no 'reads:' comment. Name what it reads." % full)
            continue
        paths.update(match.group(1).split())
    return paths, missing


def covered(path, paths):
    parts = path.split("/")
    for depth in range(len(parts), 0, -1):
        if "/".join(parts[:depth]) in paths:
            return True
    return False


def main():
    if not os.path.isdir(CHECKS):
        print("%s:1: no checks." % CHECKS)
        return 1

    paths, findings = declared()

    # Every top-level directory holding a file a check could read.
    seen = {}
    for path in tracked():
        top = path.split("/")[0]
        if top in EXEMPT or top.startswith("."):
            continue
        if os.path.splitext(path)[1] not in CHECKABLE:
            continue
        seen.setdefault(top, path)

    for top, example in sorted(seen.items()):
        if not covered(example, paths) and top not in paths:
            findings.append(
                "%s:1: no check names this. Add it to a check's reads: line."
                % top)

    for finding in findings:
        print(finding)
    if not findings:
        print("coverage: %d paths named across the checks" % len(paths))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
