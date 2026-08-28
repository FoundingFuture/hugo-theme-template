#!/usr/bin/env python3
"""A feature arrives whole, or the gate stops it.

A feature needs a manifest, a partial, a stylesheet, its words, and a
fixture page. The page shows the feature on and the feature off.

A feature that renders something it never declared is caught by the
skeleton comparison. This catches the missing pieces instead.
"""

import glob
import os
import re
import sys

try:
    import tomllib
except ModuleNotFoundError:
    try:
        import tomli as tomllib
    except ModuleNotFoundError:
        tomllib = None

MANIFESTS = next(iter(sorted(glob.glob("data/*/features"))), "data/features")
SLOTS = {
    "head", "page.before-title", "page.after-title", "page.meta",
    "page.before-body", "page.after-body", "page.footer",
    "list.item", "list.after", "body.end",
}
REQUIRED = ("name", "slot", "weight", "default")
# A component works through its shortcodes or its output formats, so it
# renders through no slot and needs no partial.
NO_SLOT = "none"


def partials_dir():
    for candidate in ("layouts/_partials", "layouts/partials"):
        if os.path.isdir(candidate):
            return candidate
    return None


def load(path):
    if tomllib is None:
        return None
    with open(path, "rb") as handle:
        return tomllib.load(handle)


def main():
    if tomllib is None:
        print("SKIP features: python 3.11 or tomli is needed to read a manifest")
        return 3

    root = partials_dir()
    if root is None:
        print("layouts:1: no partials directory.")
        return 1

    findings = []
    declared = {}

    if os.path.isdir(MANIFESTS):
        for name in sorted(os.listdir(MANIFESTS)):
            if not name.endswith(".toml"):
                continue
            path = os.path.join(MANIFESTS, name)
            try:
                manifest = load(path)
            except (OSError, ValueError) as exc:
                findings.append("%s:1: %s" % (path, exc))
                continue
            for key in REQUIRED:
                if key not in manifest:
                    findings.append("%s:1: no %s." % (path, key))
            feature = manifest.get("name") or os.path.splitext(name)[0]
            slot = manifest.get("slot")
            if slot and slot != NO_SLOT and slot not in SLOTS:
                findings.append("%s:1: slot %s is not a slot." % (path, slot))
            partial = manifest.get("partial")
            if slot != NO_SLOT and not partial:
                findings.append("%s:1: no partial, and it claims a slot." % path)
            if partial:
                declared[os.path.basename(partial)] = path
                # A component keeps its partial in its own layouts, which
                # the site mounts over the theme's.
                places = [os.path.join(root, partial)]
                for folder in ("_partials", "partials"):
                    places.append(os.path.join("features", feature, "layouts",
                                               folder, partial))
                if not any(os.path.exists(place) for place in places):
                    findings.append("%s:1: partial %s does not exist." % (path, partial))
            # A component keeps its stylesheet and its words in its own
            # directory, which the site mounts. A toggle keeps them in
            # the theme.
            roots = ["."]
            component = os.path.join("features", feature)
            if os.path.isdir(component):
                roots.insert(0, component)

            sheet = manifest.get("css")
            if sheet and not any(os.path.exists(os.path.join(root, "assets", sheet))
                                 for root in roots):
                findings.append("%s:1: css %s does not exist." % (path, sheet))
            for key in manifest.get("i18n", []):
                if not any(key_defined(key, root) for root in roots):
                    findings.append(
                        "%s:1: i18n key %s is defined nowhere it would be read."
                        % (path, key))
            page = "tools/conformance/content/kitchen-sink/features/%s.md" % feature
            if not os.path.exists(page):
                findings.append(
                    "%s:1: no fixture page at %s. A feature is exercised or it is not shipped."
                    % (path, page))

    features_dir = os.path.join(root, "features")
    if os.path.isdir(features_dir):
        for name in sorted(os.listdir(features_dir)):
            if name.endswith(".html") and name not in declared:
                findings.append(
                    "%s:1: no manifest names this partial." % os.path.join(features_dir, name))

    for finding in findings:
        print(finding)
    return 1 if findings else 0


def key_defined(key, root="."):
    path = os.path.join(root, "i18n", "en.toml")
    if not os.path.exists(path):
        return False
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    return bool(re.search(r"^\s*\[%s\]" % re.escape(key), text, re.MULTILINE) or
                re.search(r"^\s*%s\s*=" % re.escape(key), text, re.MULTILINE))


if __name__ == "__main__":
    sys.exit(main())
