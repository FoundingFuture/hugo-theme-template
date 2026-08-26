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
# What ships and what stays. Every path at the root is in one list or
# the other. A directory added tomorrow is then a decision somebody
# made, rather than one an exclusion list made for them.
PACKAGE = "package.txt"
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


def listed():
    """The root paths package.txt names, and any finding about the list."""
    if not os.path.exists(PACKAGE):
        return None, ["%s:1: missing. Name what ships and what stays." % PACKAGE]
    names = set()
    findings = []
    with open(PACKAGE, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) != 2 or parts[0] not in ("ship", "keep"):
                findings.append(
                    "%s:%d: expected 'ship <path>' or 'keep <path>'." % (PACKAGE, number))
                continue
            names.add(parts[1])
    return names, findings


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

    names, package_findings = listed()
    findings.extend(package_findings)
    if names is not None:
        roots = {path.split("/")[0] for path in tracked()}
        for root in sorted(roots - names):
            findings.append(
                "%s:1: %s is in neither list. Ship it or keep it." % (PACKAGE, root))

    for finding in findings:
        print(finding)
    if not findings:
        print("coverage: %d paths named across the checks, %d at the root"
              % (len(paths), len(names or ())))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
