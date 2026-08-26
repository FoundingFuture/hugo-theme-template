#!/usr/bin/env python3
"""Write the pull request report as one self-contained page.

A reviewer reads one page and sees what the branch changed. Which gates
ran. Which files appeared or vanished. Which page skeletons moved, and
what the last release looked like beside this build.

Nothing here is fetched. The styling is read from report.css and put in
the page. A workflow artifact is opened from a file path, with no server
behind it.
"""

import glob
import html
import json
import os
import subprocess
import sys

OUT = "tools/conformance/public/report"
PUB = "tools/conformance/public"
SNAPSHOT = "tools/conformance/snapshots/skeleton"
SCREENS = "tools/conformance/snapshots/screens"

STYLE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "report.css")


def read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def skeleton_of(root):
    out = subprocess.run(
        [sys.executable, "tools/conformance/scripts/skeleton.py", root],
        capture_output=True, text=True)
    if out.returncode not in (0, 1) or not out.stdout.strip():
        return {}
    try:
        return json.loads(out.stdout)
    except ValueError:
        return {}


def has_snapshot():
    """Whether a release has ever been tagged from this repository."""
    return os.path.isdir(SNAPSHOT) and any(
        name.endswith(".json") for name in os.listdir(SNAPSHOT))


def snapshot():
    if not os.path.isdir(SNAPSHOT):
        return {}
    tree = {}
    for name in sorted(os.listdir(SNAPSHOT)):
        if not name.endswith(".json"):
            continue
        with open(os.path.join(SNAPSHOT, name), encoding="utf-8") as handle:
            tree[name[:-len(".json")].replace("__", "/")] = json.load(handle)
    return tree


def section(title, body):
    return "<h2>%s</h2>\n%s\n" % (html.escape(title), body)


def as_none(text):
    return '<p class="none">%s</p>' % html.escape(text)


def diff_block(text):
    if not text or not text.strip():
        return None
    lines = []
    for line in text.splitlines():
        css = ""
        if line.startswith("+") and not line.startswith("+++"):
            css = "add"
        elif line.startswith("-") and not line.startswith("---"):
            css = "del"
        lines.append('<span class="%s">%s</span>' % (css, html.escape(line)))
    return "<pre>%s</pre>" % "\n".join(lines)


def page_differences(before, after):
    """Report every page whose headings, links or images moved."""
    rows = []
    for path in sorted(set(before) | set(after)):
        old, new = before.get(path), after.get(path)
        if old == new:
            continue
        if old is None:
            rows.append((path, "added", ""))
        elif new is None:
            rows.append((path, "removed", ""))
        else:
            moved = [key for key in ("h1", "headings", "links", "images", "counts")
                     if old.get(key) != new.get(key)]
            rows.append((path, "changed", ", ".join(moved)))
    return rows


def lighthouse():
    """The scores, as Lighthouse wrote them, one row a page."""
    reports = sorted(glob.glob(os.path.join(".lighthouseci", "lhr-*.json")))
    if not reports:
        return as_none("Lighthouse did not run.")
    rows = ["<table><tr><th>Page</th><th>Performance</th><th>Accessibility</th>"
            "<th>Best practices</th><th>SEO</th></tr>"]
    for path in reports:
        try:
            with open(path, encoding="utf-8") as handle:
                report = json.load(handle)
        except (OSError, ValueError):
            continue
        url = report.get("finalDisplayedUrl") or report.get("finalUrl", "")
        page = "/" + url.split("/", 3)[-1] if url.count("/") > 2 else url
        cells = []
        for name in ("performance", "accessibility", "best-practices", "seo"):
            score = report.get("categories", {}).get(name, {}).get("score")
            cells.append("%d" % round(score * 100) if score is not None else "-")
        rows.append("<tr><td>%s</td>%s</tr>"
                    % (html.escape(page),
                       "".join("<td>%s</td>" % c for c in cells)))
    rows.append("</table>")
    return "".join(rows)


def screenshots():
    """Every page whose picture moved, with the two images and the diff."""
    diffs = sorted(glob.glob(os.path.join(PUB, "screens", "*-diff.png")))
    if not diffs:
        if not os.path.isdir(SCREENS):
            return as_none("No baseline until the first release. ./c release writes one.")
        return as_none("No screenshot moved since the last tag.")
    blocks = []
    for diff in diffs:
        name = os.path.basename(diff)[: -len("-diff.png")]
        before = os.path.join(SCREENS, name + ".png")
        after = os.path.join(PUB, "screens", name + ".png")
        blocks.append(
            "<h3>%s</h3><div class=\"shots\">%s</div>"
            % (html.escape(name),
               "".join('<figure><figcaption>%s</figcaption>'
                       '<img src="%s" alt="%s of %s"></figure>'
                       % (label, os.path.relpath(image, OUT), label, html.escape(name))
                       for label, image in (("before", before), ("after", after),
                                            ("diff", diff))
                       if os.path.exists(image))))
    return "".join(blocks)


def build_times():
    """The measured scale build, beside the budget it is held to."""
    raw = read(os.path.join(PUB, "scale.txt"))
    if not raw or not raw.strip():
        return as_none("The scale build did not run.")
    seconds, pages, budget = (raw.strip().split("\t") + ["", "", ""])[:3]
    share = ""
    try:
        if float(budget):
            share = "%d%% of the budget" % round(float(seconds) / float(budget) * 100)
    except ValueError:
        share = ""
    return ("<table><tr><th>Fixture</th><th>Pages</th><th>Seconds</th>"
            "<th>Budget</th><th>Headroom</th></tr>"
            "<tr><td>scale</td><td>%s</td><td>%s</td><td>%s</td>"
            "<td class=\"muted\">%s</td></tr></table>"
            % (html.escape(pages), html.escape(seconds),
               html.escape(budget), html.escape(share)))


def main():
    os.makedirs(OUT, exist_ok=True)
    parts = ["<h1>Conformance report</h1>"]

    tally = read(os.path.join(PUB, "tally.txt"))
    parts.append(section("Gates", "<pre>%s</pre>" % html.escape(tally.strip())
                         if tally else as_none("No tally was recorded.")))

    files = diff_block(read(os.path.join(PUB, "files.diff")))
    parts.append(section("File list against the scaffold",
                         files or as_none("The theme publishes the same files as the scaffold.")))

    skel = diff_block(read(os.path.join(PUB, "skeleton.diff")))
    parts.append(section("Page skeletons against the scaffold",
                         skel or as_none("Every page has the shape the scaffold gives it.")))

    # Before the first release there is nothing to compare against.
    # An empty snapshot would read as every page being new.
    #
    # What stands in until then is the comparison against the Hugo
    # scaffold. conform makes it on every run, two sections above.
    if not has_snapshot():
        parts.append(section("Against the last release", as_none(
            "No baseline until the first release. Until then the pages are "
            "compared against the Hugo scaffold, which is the file list and "
            "page skeleton above.")))
        rows = []
    else:
        rows = page_differences(snapshot(), skeleton_of(os.path.join(PUB, "ours")))
    if rows:
        body = ["<table><tr><th>Page</th><th>Change</th><th>What moved</th></tr>"]
        for path, kind, moved in rows:
            body.append("<tr><td>%s</td><td>%s</td><td class=\"muted\">%s</td></tr>"
                        % (html.escape(path), kind, html.escape(moved)))
        body.append("</table>")
        parts.append(section("Against the last release", "".join(body)))
    elif has_snapshot():
        parts.append(section("Against the last release",
                             as_none("No page changed shape since the last tag.")))

    parts.append(section("Lighthouse", lighthouse()))
    parts.append(section("Screenshots against the last release", screenshots()))
    parts.append(section("Build time", build_times()))

    external = read(os.path.join(PUB, "external.txt"))
    parts.append(section("Third-party requests",
                         "<pre>%s</pre>" % html.escape(external.strip()) if external
                         else as_none("The build makes no third-party request.")))

    document = (
        "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width\">\n"
        "<title>Conformance report</title>\n<style>%s</style>\n</head>\n<body>\n%s\n"
        "</body>\n</html>\n" % (read(STYLE_PATH) or "", "\n".join(parts)))
    target = os.path.join(OUT, "index.html")
    with open(target, "w", encoding="utf-8") as handle:
        handle.write(document)
    print("wrote %s" % target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
