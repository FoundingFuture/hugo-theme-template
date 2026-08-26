#!/usr/bin/env python3
"""Report a partial that could be cached and is not.

Hugo prints a metrics table under --templateMetricsHints. Two of its
columns matter here. Cache potential is how often a template returned
the same markup it returned before. Cached is how often Hugo served it
from the cache instead of running it.

A template with potential and no caching runs once a page for no gain.
On the scale fixture that is two thousand needless calls.
"""

import re
import sys

# The header names the columns, and the widths vary by run, so the
# columns are found by name rather than by position.
NUMBER = re.compile(r"^\s*([\d.]+)\s*(m?s)?$")


def parse(lines):
    header = None
    rows = []
    for line in lines:
        stripped = line.rstrip()
        if not stripped.strip():
            continue
        columns = [c.strip() for c in re.split(r"\s{2,}", stripped.strip())]
        if header is None:
            lowered = [c.lower() for c in columns]
            if "template" in lowered and any("cache" in c for c in lowered):
                header = lowered
            continue
        if len(columns) == len(header):
            rows.append(dict(zip(header, columns)))
    return header, rows


def percent(value):
    try:
        return float(str(value).replace("%", "").strip())
    except (TypeError, ValueError):
        return 0.0


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "conformance/public/metrics.txt"
    with open(path, encoding="utf-8", errors="replace") as handle:
        header, rows = parse(handle.readlines())
    if not header:
        # Nothing to read is not a pass. Say so, rather than going quiet.
        print("conformance/public/metrics.txt:1: no template metrics table was found.")
        return 1

    potential = next((c for c in header if "potential" in c), None)
    cached = next((c for c in header if c.strip() == "cached" or "cached" in c), None)
    name = next((c for c in header if "template" in c), None)
    if not potential or not cached or not name:
        print("conformance/public/metrics.txt:1: the metrics table has no cache columns.")
        return 1

    findings = []
    for row in rows:
        if percent(row.get(potential)) > 0 and percent(row.get(cached)) == 0:
            findings.append(
                "%s:1: %s could be cached and is not, at %s potential."
                % (row.get(name), row.get(name), row.get(potential)))
    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
