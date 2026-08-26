#!/usr/bin/env bash
# Lighthouse over four representative pages. Chrome is needed, so this
# gate runs in CI and nowhere else.
# reads: conformance/public/ours lighthouserc.json
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

command -v lhci >/dev/null 2>&1 || { echo "SKIP perf: lighthouse-ci not installed"; exit 3; }
[ -d conformance/public/ours ] || { echo "SKIP perf: no build"; exit 3; }

# Lighthouse drives a real browser and looks for one in the places a
# system package puts it. A Playwright install puts it somewhere else,
# which is where CI and a workstation both have one.
if [ -z "${CHROME_PATH:-}" ]; then
  for candidate in \
      /usr/bin/google-chrome /usr/bin/google-chrome-stable \
      /usr/bin/chromium /usr/bin/chromium-browser /snap/bin/chromium; do
    [ -x "$candidate" ] && { CHROME_PATH="$candidate"; break; }
  done
fi
if [ -z "${CHROME_PATH:-}" ]; then
  CHROME_PATH="$(find "${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}" \
    -maxdepth 3 -type f -name chrome 2>/dev/null | sort | head -1)"
fi
[ -n "${CHROME_PATH:-}" ] || { echo "SKIP perf: no Chrome to drive"; exit 3; }
export CHROME_PATH
printf '%s\n' "perf: driving $CHROME_PATH"

lhci autorun --config=lighthouserc.json
