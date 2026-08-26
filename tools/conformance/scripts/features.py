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

import fnmatch
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

MANIFESTS = "../../data/features"


def skeleton(root):
    out = subprocess.run([sys.executable, "scripts/skeleton.py", root],
                         capture_output=True, text=True)
    if not out.stdout.strip():
        return {}
    return json.loads(out.stdout)


def declarations():
    """Every addition the manifests allow, by kind."""
    allowed = {"marked": set(), "links": set(), "images": set(),
               "counts": set(), "headings": set(), "removes": set(),
               "files": set()}
    if tomllib is None or not os.path.isdir(MANIFESTS):
        return allowed, False
    for name in sorted(os.listdir(MANIFESTS)):
        if not name.endswith(".toml"):
            continue
        with open(os.path.join(MANIFESTS, name), "rb") as handle:
            manifest = tomllib.load(handle)
        table = manifest.get("skeleton", {})
        for key in allowed:
            # The manifest calls it text, because that is what a feature
            # author is adding. The skeleton calls it marked.
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
        # The h1 is the page's own. No feature may add one or move one.
        if old.get("h1") != new.get("h1"):
            findings.append("%s:1: the h1 changed, which no feature may do." % path)

        # A heading is allowed when the container it sits in was
        # declared, the same rule the links follow.
        for row in new.get("headings", []):
            if row in old.get("headings", []):
                continue
            container = row[3] if len(row) > 3 else ""
            if container not in allowed["headings"]:
                findings.append(
                    "%s:1: a heading was added in %s, which no manifest declares."
                    % (path, container or "the content itself"))
        for row in old.get("headings", []):
            if row not in new.get("headings", []):
                findings.append("%s:1: a heading went missing when a feature was on." % path)

        # An element type that appears more often has to be named.
        for element, count in new.get("counts", {}).items():
            was = old.get("counts", {}).get(element, 0)
            if count > was and element not in allowed["counts"]:
                findings.append(
                    "%s:1: %d more <%s> than with the feature off, and no manifest declares it."
                    % (path, count - was, element))
            if count < was and element not in allowed["removes"]:
                findings.append(
                    "%s:1: %d fewer <%s> when a feature was on, and no manifest "
                    "declares removing one." % (path, was - count, element))
        added = [row for row in new.get("marked", []) if row not in old.get("marked", [])]
        for selector, _text in added:
            if selector not in allowed["marked"]:
                findings.append(
                    "%s:1: %s appeared, and no manifest declares it." % (path, selector))
        # A link is allowed when its container was declared. That lets
        # a table of contents add links, without opening the door to
        # every other link on the page.
        for row in new.get("links", []):
            if row in old.get("links", []):
                continue
            container = row[2] if len(row) > 2 else ""
            if container not in allowed["links"]:
                findings.append(
                    "%s:1: a link was added in %s, which no manifest declares."
                    % (path, container or "the content itself"))
        extra_images = [row for row in new.get("images", [])
                        if row not in old.get("images", [])]
        if extra_images and not allowed["images"]:
            findings.append(
                "%s:1: %d image(s) added, and no manifest declares any."
                % (path, len(extra_images)))
    return findings


def published(root):
    """Every file a build wrote, as paths relative to its root."""
    out = set()
    for folder, dirs, names in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in ("css", "js", "fonts"))
        for name in names:
            out.add(os.path.relpath(os.path.join(folder, name), root).replace(os.sep, "/"))
    return out


def compare_files(off, on, allowed):
    """A feature may publish a file, if its manifest says which."""
    findings = []
    for path in sorted(on - off):
        if not any(fnmatch.fnmatch(path, pattern) for pattern in allowed["files"]):
            findings.append(
                "%s:1: published only with the features on, and no manifest declares it."
                % path)
    for path in sorted(off - on):
        findings.append("%s:1: vanishes when the features are on." % path)
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
    findings.extend(compare_files(published("public/ours-off"),
                                  published("public/ours"), allowed))

    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
