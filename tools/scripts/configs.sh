#!/usr/bin/env bash
# Write the fixture configs that are generated, and the artefact they
# read.
#
# config/ours reads the theme the way a downloader does, out of
# dist/<slug>/. config/off is the same with the features switched off
# and no component mounted. config/dev mounts the repository instead,
# which is what serve reads so that an edit shows up without a repack.
#
# Cheap enough to run before every build. That is what keeps a config
# from going stale against the manifests behind it.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

tools/scripts/package.sh >/dev/null

mkdir -p tools/conformance/config/ours tools/conformance/config/off \
         tools/conformance/config/dev
tools/scripts/ours-config.sh > tools/conformance/config/ours/hugo.toml
tools/scripts/off-config.sh  > tools/conformance/config/off/hugo.toml
tools/scripts/dev-config.sh  > tools/conformance/config/dev/hugo.toml
