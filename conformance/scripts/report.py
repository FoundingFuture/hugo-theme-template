#!/usr/bin/env python3
"""Write the pull request report as one self-contained page.

A reviewer reads one page and sees what the branch changed: which gates
ran, which files appeared or vanished, which page skeletons moved, and
what the last release looked like beside what this build looks like.

Nothing here is fetched. The page carries its own styling, because a
workflow artifact is opened from a file path with no server behind it.
"""

import html
import json
import os
import subprocess
import sys

OUT = "conformance/public/report"
PUB = "conformance/public"
SNAPSHOT = "conformance/snapshots/skeleton"

STYLE = """
:root { color-scheme: light dark; --bg:#fff; --fg:#111; --line:#d0d0d0;
        --add:#1a7f37; --del:#b3261e; --muted:#666; }
@media (prefers-color-scheme: dark) {
  :root { --bg:#111; --fg:#eee; --line:#333; --add:#4ac26b; --del:#ff7b72; --muted:#999; }
}
body { background:var(--bg); color:var(--fg); margin:0 auto; max-width:60rem;
       padding:2rem 1rem; font:16px/1.6 system-ui, sans-serif; }
h1 { font-size:1.6rem; } h2 { font-size:1.2rem; margin-top:2.5rem; }
table { border-collapse:collapse; width:100%; }
th, td { border-bottom:1px solid var(--line); padding:.4rem .6rem; text-align:left;
         vertical-align:top; }
pre { overflow-x:auto; background:color-mix(in srgb, var(--fg) 6%, transparent);
      padding:.8rem; border-radius:4px; }
.add { color:var(--add); } .del { color:var(--del); }
.muted { color:var(--muted); }
.none { color:var(--muted); font-style:italic; }
"""


def read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def skeleton_of(root):
    out = subprocess.run(
        [sys.executable, "conformance/scripts/skeleton.py", root],
        capture_output=True, text=True)
    if out.returncode not in (0, 1) or not out.stdout.strip():
        return {}
    try:
        return json.loads(out.stdout)
    except ValueError:
        return {}


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

    rows = page_differences(snapshot(), skeleton_of(os.path.join(PUB, "ours")))
    if rows:
        body = ["<table><tr><th>Page</th><th>Change</th><th>What moved</th></tr>"]
        for path, kind, moved in rows:
            body.append("<tr><td>%s</td><td>%s</td><td class=\"muted\">%s</td></tr>"
                        % (html.escape(path), kind, html.escape(moved)))
        body.append("</table>")
        parts.append(section("Against the last release", "".join(body)))
    else:
        parts.append(section("Against the last release",
                             as_none("No page changed shape since the last tag.")))

    parts.append(section("Build time", build_times()))

    external = read(os.path.join(PUB, "external.txt"))
    parts.append(section("Third-party requests",
                         "<pre>%s</pre>" % html.escape(external.strip()) if external
                         else as_none("The build makes no third-party request.")))

    document = (
        "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width\">\n"
        "<title>Conformance report</title>\n<style>%s</style>\n</head>\n<body>\n%s\n"
        "</body>\n</html>\n" % (STYLE, "\n".join(parts)))
    target = os.path.join(OUT, "index.html")
    with open(target, "w", encoding="utf-8") as handle:
        handle.write(document)
    print("wrote %s" % target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
