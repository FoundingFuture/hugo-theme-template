#!/usr/bin/env python3
"""Check the theme's own metadata.

The files it reads come out of the artefact, dist/<slug>/. That is what
themes.gohugo.io clones and what a downloader unzips. A file present
here and missing there is a file nobody receives. What the repository
must not carry is still asked of the repository, since a commit is what
carries it.

Two modes. The default is structural: the files exist, the versions
agree, and no build output is tracked. That holds from the first commit.

--listing is the themes.gohugo.io side. A description, tags, features
and two screenshots. A theme in development has none of those yet.
Demanding them on day one would mean shipping a blank screenshot to
satisfy a gate. They are needed to release, so the release gate asks.
"""

import os
import re
import subprocess
import sys

# Present from the first commit, because bootstrap writes them.
STRUCTURAL = ["name", "license", "licenselink", "homepage", "min_version"]
FORBIDDEN = ["resources/_gen", "public", ".hugo_build.lock"]
# A theme is downloaded by everyone who installs it, and nothing it
# carries needs a megabyte. A bootstrap workflow once committed a
# twenty-one megabyte tarball here, and nothing noticed.
MAX_TRACKED_BYTES = 1024 * 1024
SCREENSHOTS = {"images/screenshot.png": (1500, 1000), "images/tn.png": (900, 600)}


def artefact():
    """Where the theme is, as somebody who installed it would find it."""
    root = os.environ.get("ARTEFACT")
    if root:
        return root
    try:
        slug = subprocess.run(["tools/scripts/slug.sh"], capture_output=True,
                              text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "."
    path = os.path.join("dist", slug)
    return path if os.path.isdir(path) else "."


SHIPPED = artefact()


def shipped(name):
    return os.path.join(SHIPPED, name)


def scalar(text, key):
    match = re.search(r"^\s*%s\s*=\s*(.+)$" % re.escape(key), text, re.MULTILINE)
    return match.group(1).strip() if match else None


def png_size(path):
    """Read width and height from the PNG header, with no image library."""
    with open(path, "rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return (int.from_bytes(header[16:20], "big"),
            int.from_bytes(header[20:24], "big"))


def untracked():
    """Files a commit would add: present, not tracked, not ignored."""
    try:
        out = subprocess.run(
            ["git", "status", "--porcelain", "--untracked-files=all"],
            capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return []
    return [line[3:] for line in out.splitlines() if line.startswith("?? ")]


def tracked():
    try:
        out = subprocess.run(["git", "ls-files"], capture_output=True,
                             text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return []
    return out.splitlines()


def listing_checks():
    """What themes.gohugo.io needs before it can list the theme."""
    findings = []
    if os.path.exists(shipped("theme.toml")):
        with open(shipped("theme.toml"), encoding="utf-8") as handle:
            text = handle.read()
        for key in ("description", "tags", "features", "demosite"):
            value = scalar(text, key)
            if value is None:
                findings.append("theme.toml:1: no %s." % key)
            elif value in ('""', "''", "[]"):
                findings.append("theme.toml:1: %s is empty. The listing shows it." % key)
    else:
        findings.append("theme.toml:1: missing.")

    for path, want in SCREENSHOTS.items():
        if not os.path.exists(shipped(path)):
            findings.append("%s:1: missing. themes.gohugo.io shows it." % path)
            continue
        size = png_size(shipped(path))
        if size is None:
            findings.append("%s:1: not a PNG." % path)
        elif size != want:
            findings.append("%s:1: is %dx%d, must be %dx%d."
                            % (path, size[0], size[1], want[0], want[1]))

    if os.path.exists(shipped("README.md")):
        with open(shipped("README.md"), encoding="utf-8") as handle:
            readme = handle.read()
        for target in re.findall(r"!\[[^\]]*\]\(([^)]+)\)", readme):
            if not target.startswith(("http://", "https://")):
                findings.append(
                    "README.md:1: image %s is relative. themes.gohugo.io needs an absolute URL."
                    % target)
    return findings


def main():
    if "--listing" in sys.argv:
        findings = listing_checks()
        for finding in findings:
            print(finding)
        return 1 if findings else 0

    findings = []

    if not os.path.exists(shipped("theme.toml")):
        findings.append("theme.toml:1: missing. themes.gohugo.io reads it.")
    else:
        with open(shipped("theme.toml"), encoding="utf-8") as handle:
            text = handle.read()
        for key in STRUCTURAL:
            if scalar(text, key) is None:
                findings.append("theme.toml:1: no %s." % key)

    pinned = None
    if os.path.exists(".hugo-version"):
        with open(".hugo-version", encoding="utf-8") as handle:
            pinned = handle.read().strip()

    if os.path.exists(shipped("hugo.toml")):
        with open(shipped("hugo.toml"), encoding="utf-8") as handle:
            config = handle.read()
        minimum = scalar(config, "min")
        if minimum is None:
            findings.append("hugo.toml:1: no [module.hugoVersion] min.")
        elif pinned:
            got = minimum.strip("\"'")
            if tuple(int(x) for x in got.split(".")) > tuple(
                    int(x) for x in pinned.split(".")):
                findings.append(
                    "hugo.toml:1: min %s is newer than .hugo-version %s." % (got, pinned))

    if not os.path.exists(shipped("LICENSE")):
        findings.append("LICENSE:1: missing.")

    for path in tracked():
        for bad in FORBIDDEN:
            if path == bad or path.startswith(bad + "/"):
                findings.append("%s:1: tracked, and must not be." % path)
        try:
            size = os.path.getsize(path)
        except OSError:
            continue
        if size > MAX_TRACKED_BYTES:
            findings.append(
                "%s:1: %.1f MB is tracked. Nothing here needs a megabyte."
                % (path, size / 1024 / 1024))

    # What a commit would add, as well as what one already has. The rule
    # read tracked files only, so it could not see a browser sitting
    # untracked in the working tree. The bootstrap run commits whatever
    # it finds there, and a browser is hundreds of megabytes.
    for path in untracked():
        try:
            size = os.path.getsize(path)
        except OSError:
            continue
        if size > MAX_TRACKED_BYTES:
            findings.append(
                "%s:1: %.1f MB is untracked and not ignored. A commit would take it."
                % (path, size / 1024 / 1024))

    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
