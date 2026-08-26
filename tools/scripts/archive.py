#!/usr/bin/env python3
"""Write, list and extract the artefact's zip.

Python already reads most of what the checks read. zip and unzip would
be two more things to install, and Git for Windows ships neither. A
theme made here is meant to be developed there too, so the standard
library does all three.

    archive.py write <directory> <zip>. It goes in under its own name.
    archive.py list <zip>. One entry per line.
    archive.py sizes <zip>. The uncompressed size, then the entry.
    archive.py extract <zip> <directory>. Unpacked into that directory.
"""

import os
import sys
import zipfile

# zipfile stamps each member with the file's mtime, so the same commit
# packed on two machines gives two different zips. The contents match,
# the order matches, and the bytes differ. Nothing compares zips today,
# and a release people can checksum is worth four lines.
STAMP = (1980, 1, 1, 0, 0, 0)
MODE = 0o644 << 16


def write(source, target):
    source = source.rstrip("/\\")
    parent = os.path.dirname(source) or "."
    os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
    # Sorted, so the same tree always writes the same listing. A walk
    # returns what the filesystem happens to hold. A check reading the
    # first entry would answer differently by machine.
    paths = []
    for folder, folders, names in os.walk(source):
        folders.sort()
        for name in sorted(names):
            paths.append(os.path.join(folder, name))
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(paths):
            name = os.path.relpath(path, parent).replace(os.sep, "/")
            entry = zipfile.ZipInfo(name, STAMP)
            entry.compress_type = zipfile.ZIP_DEFLATED
            # The mode a downloader unpacks, rather than the one this
            # checkout happens to carry.
            entry.external_attr = MODE
            with open(path, "rb") as handle:
                archive.writestr(entry, handle.read())
    return 0


def listing(target, sizes=False):
    with zipfile.ZipFile(target) as archive:
        for info in archive.infolist():
            if sizes:
                print("%d %s" % (info.file_size, info.filename))
            else:
                print(info.filename)
    return 0


def extract(target, into):
    with zipfile.ZipFile(target) as archive:
        # A member can name a path outside the destination. That is
        # how a zip walks out of the directory it was given.
        root = os.path.abspath(into)
        for name in archive.namelist():
            where = os.path.abspath(os.path.join(root, name))
            if where != root and not where.startswith(root + os.sep):
                sys.stderr.write("%s: escapes the destination\n" % name)
                return 1
        archive.extractall(into)
    return 0


def main():
    argv = sys.argv[1:]
    if not argv:
        sys.stderr.write(__doc__)
        return 2
    verb = argv[0]
    try:
        if verb == "write" and len(argv) == 3:
            return write(argv[1], argv[2])
        if verb == "list" and len(argv) == 2:
            return listing(argv[1])
        if verb == "sizes" and len(argv) == 2:
            return listing(argv[1], sizes=True)
        if verb == "extract" and len(argv) == 3:
            return extract(argv[1], argv[2])
    except (OSError, zipfile.BadZipFile) as problem:
        sys.stderr.write("%s\n" % problem)
        return 1
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
