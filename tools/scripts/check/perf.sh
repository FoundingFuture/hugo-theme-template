#!/usr/bin/env bash
# Lighthouse over four representative pages. Chrome is needed, so this
# gate runs in CI and nowhere else.
# reads: tools/conformance/public/ours tools/lighthouserc.json
set -uo pipefail
# lighthouse-ci writes .lighthouseci beside whatever directory it is run
# from, and it takes no flag for that. Running from tools/ is what keeps
# the reports out of the theme root.
cd "$(dirname "$0")/../.." || exit 1

# Runs from tools/, so the locate path sits one level up from the
# one every other check uses.
bin="$(scripts/tools.sh lhci 2>/dev/null)" && PATH="$bin:$PATH"
command -v lhci >/dev/null 2>&1 || {
  echo "SKIP perf: lighthouse-ci not installed. ./c setup full fetches it"; exit 3; }
[ -d conformance/public/ours ] || { echo "SKIP perf: no build"; exit 3; }

# Lighthouse drives a real browser and looks for one in the places a
# system package puts it. A Playwright install puts it somewhere else,
# which is where CI and a workstation both have one.
if [ -z "${CHROME_PATH:-}" ]; then
  for candidate in \
      /usr/bin/google-chrome /usr/bin/google-chrome-stable \
      /usr/bin/chromium /usr/bin/chromium-browser /snap/bin/chromium \
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
      "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
      "/Applications/Chromium.app/Contents/MacOS/Chromium" \
      "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"; do
    [ -x "$candidate" ] && { CHROME_PATH="$candidate"; break; }
  done
fi
if [ -z "${CHROME_PATH:-}" ]; then
  # The Playwright cache sits under .cache on Linux and under
  # Library/Caches on a Mac. The Mac browser inside is branded
  # Google Chrome for Testing.
  for cache in "${PLAYWRIGHT_BROWSERS_PATH:-}" "$HOME/.cache/ms-playwright" \
      "$HOME/Library/Caches/ms-playwright"; do
    [ -d "$cache" ] || continue
    CHROME_PATH="$(find "$cache" -maxdepth 6 -type f \
      \( -name chrome -o -name Chromium -o -name 'Google Chrome for Testing' \) \
      2>/dev/null | sort | head -1)"
    [ -n "$CHROME_PATH" ] && break
  done
fi
[ -n "${CHROME_PATH:-}" ] || { echo "SKIP perf: no Chrome to drive"; exit 3; }
export CHROME_PATH
printf '%s\n' "perf: driving $CHROME_PATH"

lhci autorun --config=lighthouserc.json
