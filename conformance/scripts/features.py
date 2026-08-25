#!/usr/bin/env python3
"""Check that a feature adds what it declared, and nothing besides.

Three builds are compared. The reference scaffold, the theme with every
feature switched off, and the theme with every feature at its default.

With the features off the theme has to match the scaffold exactly. With
them on, the only differences allowed are the ones the manifests declare
in their skeleton table. A feature that quietly changes a heading, a
link or an element it never mentioned is stopped here.

This replaces a hand-kept list of things to ignore. The list would go
stale. A declaration cannot, because the build reads it.
"""

import json
import os
import subprocess
import sys

try:
    import tomllib
except ModuleNotFoundError:
    try:
        import tomli as tomllib
    except ModuleNotFoundError:
        tomllib = None

MANIFESTS = "../data/features"


def skeleton(root):
    out = subprocess.run([sys.executable, "scripts/skeleton.py", root],
                         capture_output=True, text=True)
    if not out.stdout.strip():
        return {}
    return json.loads(out.stdout)


def declarations():
    """Every addition the manifests allow, by kind."""
    allowed = {"marked": set(), "links": set(), "images": set(), "counts": set()}
    if tomllib is None or not os.path.isdir(MANIFESTS):
        return allowed, False
    for name in sorted(os.listdir(MANIFESTS)):
        if not name.endswith(".toml"):
            continue
        with open(os.path.join(MANIFESTS, name), "rb") as handle:
            manifest = tomllib.load(handle)
        table = manifest.get("skeleton", {})
        for key in allowed:
            source = table.get("text" if key == "marked" else key, [])
            allowed[key].update(source)
    return allowed, True


def compare(before, after, allowed):
    """Report a difference that no manifest accounts for."""
    findings = []
    for path in sorted(set(before) | set(after)):
        old = before.get(path)
        new = after.get(path)
        if old is None:
            findings.append("%s:1: the page appears only with features on." % path)
            continue
        if new is None:
            findings.append("%s:1: the page vanishes when features are on." % path)
            continue
        for key in ("h1", "headings", "counts"):
            if key == "counts":
                continue
            if old.get(key) != new.get(key):
                findings.append("%s:1: %s changed, and no feature declared it." % (path, key))
        added = [row for row in new.get("marked", []) if row not in old.get("marked", [])]
        for selector, _text in added:
            if selector not in allowed["marked"]:
                findings.append(
                    "%s:1: %s appeared, and no manifest declares it." % (path, selector))
        for key in ("links", "images"):
            extra = [row for row in new.get(key, []) if row not in old.get(key, [])]
            if extra and not allowed[key]:
                findings.append(
                    "%s:1: %d %s added, and no manifest declares any." % (path, len(extra), key))
    return findings


def main():
    allowed, readable = declarations()
    if not readable:
        print("SKIP features: no manifest reader")
        return 3
    off = skeleton("public/ours-off")
    on = skeleton("public/ours")
    reference = skeleton("public/hugo")
    if not off or not on:
        print("SKIP features: build public/ours and public/ours-off first")
        return 3

    findings = []
    for path in sorted(set(reference) | set(off)):
        if reference.get(path) != off.get(path):
            findings.append(
                "%s:1: with every feature off the theme still differs from the scaffold."
                % path)
    findings.extend(compare(off, on, allowed))

    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
