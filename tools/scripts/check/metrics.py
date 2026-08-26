#!/usr/bin/env python3
"""Report a partial that is expensive and repeats itself.

Hugo prints a metrics table under --templateMetricsHints. Cache
potential is how often a template returned markup it had returned
before. Cumulative duration is what it cost across the build.

Potential alone is not a fault. A partial reporting a reading time
returns the same words whenever two pages read alike. Caching it by page
would be wrong. On a synthetic fixture that repetition says more about
the fixture than about the theme.

Cost with potential is a fault. A partial running a site-wide query in a
per-page loop repeats its answer and dominates the table. That is the
fault the scale fixture exists to find.

Both together are the gate. Everything measured is reported either way.
"""

import re
import sys

# Duration, average, maximum, potential, percent cached, cached, total,
# then the template name. The widths vary by run, so the row is matched
# by shape rather than by column position.
ROW = re.compile(
    r"^\s+([\d.]+)(ms|µs|s|ns)\s+\S+\s+\S+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s*$")
UNITS = {"ns": 1e-6, "µs": 1e-3, "ms": 1.0, "s": 1000.0}

MIN_POTENTIAL = 50
MIN_SHARE = 15.0


def rows(path):
    out = []
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = ROW.match(line)
            if not match:
                continue
            duration = float(match.group(1)) * UNITS[match.group(2)]
            out.append({
                "ms": duration,
                "potential": int(match.group(3)),
                "cached": int(match.group(5)),
                "calls": int(match.group(6)),
                "name": match.group(7),
            })
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "tools/conformance/public/metrics.txt"
    measured = rows(path)
    if not measured:
        # Nothing read is not a pass. A gate with no input says so.
        print("%s:1: no template metrics table was found." % path)
        return 1

    total = sum(row["ms"] for row in measured) or 1.0
    for row in measured:
        row["share"] = row["ms"] / total * 100

    findings = []
    for row in sorted(measured, key=lambda r: -r["share"]):
        if (row["potential"] >= MIN_POTENTIAL and row["cached"] == 0
                and row["share"] >= MIN_SHARE):
            findings.append(
                "%s:1: %.0f%% of template time at %d%% cache potential, uncached. "
                "Cache it, or stop repeating the work."
                % (row["name"], row["share"], row["potential"]))

    print("metrics: %d templates, %.0f ms of template time" % (len(measured), total))
    for row in sorted(measured, key=lambda r: -r["share"])[:5]:
        print("  %5.1f%%  %3d%% potential  %s" % (row["share"], row["potential"], row["name"]))
    for finding in findings:
        print(finding)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
