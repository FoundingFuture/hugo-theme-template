#!/usr/bin/env python3
"""Print a config that switches every feature off.

Generated rather than kept, so a feature added today is off in the
comparison build today, with no second place to remember.
"""

import os
import sys

MANIFESTS = "../data/features"


def main():
    names = []
    if os.path.isdir(MANIFESTS):
        for name in sorted(os.listdir(MANIFESTS)):
            if name.endswith(".toml"):
                names.append(os.path.splitext(name)[0])
    sys.stdout.write("# Written by conform.sh. Do not edit.\n")
    # featuresOff outranks front matter. A fixture page turning its own
    # feature on would otherwise keep it on in the comparison build.
    sys.stdout.write("[params]\n  featuresOff = true\n[params.features]\n")
    for name in names:
        sys.stdout.write('  "%s" = false\n' % name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
