#!/usr/bin/env python3
"""Print one manifest as a row for the feature table."""

import sys

try:
    import tomllib
except ModuleNotFoundError:
    try:
        import tomli as tomllib
    except ModuleNotFoundError:
        sys.exit(0)


def main():
    with open(sys.argv[1], "rb") as handle:
        manifest = tomllib.load(handle)
    print("%-18s %-10s %-18s %-8s %s" % (
        manifest.get("name", "?"), "installed", manifest.get("slot", "?"),
        "on" if manifest.get("default") else "off",
        manifest.get("level", "toggle")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
